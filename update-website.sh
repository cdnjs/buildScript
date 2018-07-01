#!/usr/bin/env bash

trap "exit 1" EXIT

function init() {
    pth="$(setBasePath)"
    . "$pth/config.sh"

    updateMeta="$forceUpdateMeta"
    updateRepo="$forceUpdateRepo"

    export PATH="$path:$PATH"

    NVM_DIR=$HOME/.nvm
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        . "$NVM_DIR/nvm.sh" --no-use
        nvm install 8
    fi

    if [[ ! $timeout =~ ^[0-9]+$ ]] || [[ $timeout -le 3 ]]; then
        timeout=3
    fi

    eval logPath="$logPath"
    if [ -z "$logPath" ] || [ ! -d "$logPath" ] || [ ! -w "$logPath" ]; then
        logPath="$pth"
    fi

    [[ "$logMode" = "clean" ]] && rm -f "$logPath/$logFile"

    . "$pth/colorEcho/dist/ColorEcho.bash" &> /dev/null || {
        git -C "$pth" submodule update --init
        . "$pth/colorEcho/dist/ColorEcho.bash"
    }
}

function setBasePath() {
    dirname "$(realpath "${BASH_SOURCE[0]}")"
}

function git-checkout-master-if-needed() {
    currentBranch="$(git branch | awk '{ if ("*" == $1) print $2}')"
    [[ "$currentBranch" = "master" ]] || run_retry git checkout master
}

function git-reset-hard-if-needed() {
    if ! git diff --quiet; then
        output Info "Repo diff found, so reset!"
        run_retry git reset --hard
    else
        output Info "Repo diff not found, so do not reset!"
    fi
}

function output() {
    echo "$(date) [$1] $2" >> "$logPath/$logFile"
    case "$1" in
        "Warn" )
            echo.Red "$2"
        ;;
        "Success" )
            echo.Green "$2"
        ;;
        "Info" )
            echo.Cyan "$2"
        ;;
        *)
            echo "$1"
        ;;
    esac
    if [ ! -z "$3" ] && [ "$3" = "chat-room" ]; then
        curl --silent -d message="[cronjob] $2" "$gitterHook" > /dev/null || output Warn "Error on curl!!! Message may not be posted on our gitter chatroom"
        curl --silent -X POST --data-urlencode 'payload={"channel": "#'"$slackChannel"'", "username": "buildScript", "text": "'"$2"'", "icon_emoji": ":building_construction:"}' "$slackHook" > /dev/null || output Warn "Error on curl!!! Message may not be posted on our Slack chatroom"
    fi
}

function error() {
    local MSG
    if [ "$#" = "0" ]; then
        MSG="Error"
    else
        MSG="$*";
    fi
    output Warn "$MSG, pwd='$(pwd)'" chat-room
    exit 1
}

function run() {
    run_retry_times 1 "$*"
}

function run_retry() {
    run_retry_times "${retryTimes}" "$*"
}

function run_retry_times() {
    local timesLeft="${1}"
    local timesLeftOrigin="${1}"
    shift
    while [ "$timesLeft" -ge 1 ]; do
        timesLeft="$((timesLeft - 1))"
        if [ $((timesLeftOrigin - timesLeft)) -gt 1 ]; then
            sleep 3
            echo "$(date) [command (try times: $((timesLeftOrigin - timesLeft))/${timesLeftOrigin})] $*" >> "$logPath/$logFile"
        else
            echo "$(date) [command] $*" >> "$logPath/$logFile"
        fi

        local isBuiltIn=false
        local cmd
        cmd="$(echo "$1" | awk '{print $1}' )"
        if type "$cmd" &> /dev/null; then
            local temp
            temp="$(type "$cmd" | head -n 1)"
            [[ "$temp" = "$cmd is a shell builtin" ]] && isBuiltIn=true
        else
            error "'$*' command not found!"
        fi

        if [ "$isBuiltIn" = "false" ]; then
            nice -n "$nice" timelimit -q -s 9 -t $((timeout - 2)) -T "$timeout" "$*" || continue
        else
            "$*" || continue
        fi
        return
    done
    error "Got error while running command: '$*'"
}

function build() {

    [[ -d "$basePath/$mainRepo" ]] || error "Main repo  '$basePath/$mainRepo' not found, exit now."

    [[ -d "$basePath/$webRepo" ]] || error "website repo '$basePath/$webRepo' not found, exit now."

    output Info "Start date time: $(date)"
    output Info "Start website/api/index building process on $serverOwner's server ..." chat-room
    output Info "PATH=$PATH"
    output Info "bash path: $(type bash)"
    output Info "bash version: $BASH_VERSION"
    [[ -z "$NVM_BIN" ]] || output Info "nvm version: $(nvm --version)"
    output Info "nodejs path: $(type node)"
    output Info "nodejs version: $(node --version)"
    output Info "npm path: $(type npm)"
    output Info "npm version: $(npm --version)"
    output Info "git path: $(type git)"
    output Info "git version: $(git --version)"

    output Info "Reset repository to prevent unstaged changes break the build"
    run cd "$basePath/$mainRepo"
    git-reset-hard-if-needed

    if [ "$hasLocalRepo" = true ] && [ -d "$basePath" ]; then
        output Success "Exist cdnjs local repo, fetch objects from local branch first"
        run_retry git fetch local
    else
        output Info "Local repo not found, will grab object(s) from GitHub"
    fi

    git-checkout-master-if-needed

    updated=false
    output Info "Pull cdnjs main repo with rebase from origin(GitHub)"
    run_retry git fetch origin master --tags
    if [ "$(run git log --oneline -1 origin/master)" != "$(run git log --oneline -1 master)" ]; then
        run_retry git rebase origin/master master
        updated=true
    fi

    output Info "Current commit: $(run git log --pretty='format:%h - %s - %an %ai' -1)"
    if [ "$updated" = false ] && [ "$updateMeta" = false ]; then
        msg="Cdnjs main repo is up to date, no need to rebuild";
        output Info "$msg" chat-room
    else
        msg="Cdnjs main repo updates found! Start the rebuild rebuild process"
        output Info "$msg" chat-room
        msg="Make sure npm package dependencies, do npm install && npm update"
        output Info "$msg"
        run_retry npm install --no-save
        run_retry npm update --no-save
        msg="Run npm test before building the meta data/artifacts"
        output Info "$msg"
        run npm test -- --silent
        msg="Reset and checkout website repository to meta branch"
        output Info "$msg"
        (run cd "$basePath/$webRepo" && git-reset-hard-if-needed)
        run_retry git -C "$basePath/$webRepo" checkout meta
        msg="Rebuild meta data phase 1"
        output Info "$msg" chat-room
        run_retry node build/packages.json.js

        msg="Rebuild meta data phase 2"
        output Info "$msg" chat-room
        run cd "$basePath/$webRepo"
        msg="Make sure npm package dependencies, do npm install & npm update"
        output Info "$msg" chat-room
        run_retry npm install --no-save
        run_retry npm update --no-save
        run_retry node update.js

        msg="Commit meta data update in website repo"
        output Info "$msg" chat-room
        for file in atom.xml packages.min.json rss.xml sitemap.xml; do
            run_retry git add public/$file
        done
        run_retry git add sri
        run_retry git commit --message="meta data"

        updateMeta=true
    fi

    output Info "Change directory into website repo"
    run cd "$basePath/$webRepo"

    output Info "Reset repository to prevent unstaged changes break the build"
    git-reset-hard-if-needed
    git-checkout-master-if-needed

    output Info "Pull website repo with rebase from origin(Repo)"
    webstatus="$(run_retry git pull --tags --rebase origin master | tail -n 1)"
    output Info "Current commit: $(run git log --pretty='format:%h - %s - %an %ai' -1)"
    if [ "$webstatus" = "Current branch master is up to date." ] || [ "$webstatus" = "Already up-to-date." ]; then
        msg="Cdnjs website repo is up to date"
        $updateMeta || msg="$msg too, no need to deploy.";
        $updateMeta && msg="$msg, but we'll still deploy artifacts since main repo has updates.";
        output Info "$msg" chat-room
    else
        msg="Cdnjs website repo updates found!"
        output Info "$msg" chat-room
        updateRepo=true
    fi

    if [ "$updateRepo" = true ]; then
        output Info "Update/Initial submodule under website repo" chat-room
        run_retry git submodule update --init

        msg="Make sure npm package dependencies, do npm install & npm update"
        output Info "$msg" chat-room
        run_retry npm install --no-save
        run_retry npm update --no-save
    fi

    msg="Rebase website's meta branch on master"
    output Info "$msg"
    webstatus="$(run_retry git rebase master meta)"
    if [[ "$webstatus" != "Current branch meta is up to date." ]] && [[ "$webstatus" != "Already up-to-date." ]]; then
        updateRepo=true
    fi

    if [ "$updateMeta" = true ]; then
        msg="Now push and deploy website & api"
        output Info "$msg" chat-room
        for remote in heroku heroku2; do
            run_retry git push "$remote" meta:master -f &
            sleep 3
        done
        [[ "$pushMetaOnGitHub" = true ]] && run_retry git push origin meta -f &
        if [ ! -z "$githubToken" ] && [ ! -z "$algoliaToken" ]; then
            msg="Now rebuild algolia search index"
            output Info "$msg" chat-room
            export GITHUB_OAUTH_TOKEN="$githubToken"
            export ALGOLIA_API_KEY="$algoliaToken"
            run_retry node reindex.js
            run_retry git add GitHub.repos.meta.json
            run_retry git commit --amend --no-edit
            unset GITHUB_OAUTH_TOKEN
            unset ALGOLIA_API_KEY
        else
            error "Missing GitHub or algolia api key, cannot rebuild the searching index"
        fi
        wait
    elif [ "$updateRepo" = true ]; then
        msg="Now push and deploy website and api"
        output Info "$msg" chat-room
        for remote in heroku heroku2; do
            run_retry git push "$remote" meta:master -f &
            sleep 3
        done
        [[ "$pushMetaOnGitHub" = true ]] && run_retry git push origin meta -f &
        wait
    else
        msg="Didn't update anything, no need to push or deploy."
        output Info "$msg" chat-room
    fi

    msg="Update finished."
    output Success "$msg" chat-room
    output Info "End date time: $(date)"
}

if [ "$1" = "build" ]; then
    set +e
    init
    build
fi

trap - EXIT
