#!/usr/bin/env bash

set -e

pth="$(dirname $(readlink -f $0))"

. "$pth/config.sh"

updateMeta=$forceUpdateMeta
updateRepo=$forceUpdateRepo

export PATH="$path:$PATH"

if [[ ! $timeout =~ ^[0-9]+$ ]] || [ $timeout -le 3 ]; then
    timeout=3
fi

eval logPath=$logPath
if [ -z "$logPath" ] || [ ! -d "$logPath" ] || [ ! -w "$logPath" ] ; then
    logPath=$pth
fi

if [ "$logMode" = "clean" ]; then
    rm -f $logPath/$logFile
fi

. "$pth/colorEcho/dist/ColorEcho.bash"

function output()
{
    echo "`date` [$1] $2" >> $logPath/$logFile
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
    esac
    if [ ! -z "$3" ] && [ "$3" = "gitter" ]; then
        curl --silent -d message="[cronjob] $2" "$gitterHook" > /dev/null || output Warn "Error on curl!!! Message may not be posted on our gitter chatroom"
    fi
}

function error()
{
    if [ "$#" = "0" ]; then
        MSG="Error"
    else
        MSG="$@";
    fi
    output Warn "$MSG, pwd='`pwd`'" gitter
    exit 1
}

function run()
{
    echo "`date` [command] $@" >> $logPath/$logFile

    local isBuiltIn=false
    type $1 &> /dev/null
    if [ $? -eq 0 ]; then
        local temp="`type $1 | head -n 1`"
        if [ "$temp" = "$1 is a shell builtin" ]; then
            isBuiltIn=true
        fi
    fi

    if [ "$isBuiltIn" = "false" ]; then
        nice -n $nice timelimit -q -s 9 -t $((timeout - 2)) -T $timeout "$@"
        exitStatus=$?
        if [ $exitStatus -eq 137 ]; then
            error "Got timeout($timeout sec) while running command: '$@'"
        elif [ $exitStatus -ne 0 ]; then
            error "Got error while running command: '$@'"
        fi
    else
        "$@" || error "Got error while running command: '$@'"
    fi
}

if [ ! -d "$basePath/$mainRepo" ]; then
    error "Main repo  '$basePath/$mainRepo' not found, exit now."
fi

if [ ! -d "$basePath/$webRepo" ]; then
    error "website repo '$basePath/$webRepo' not found, exit now."
fi

output Info "Start date time: `date`"
output Info "Start website/api/index building process on $serverOwner's server ..." gitter

output Info "Reset repository to prevent unstaged changes break the build"
run cd "$basePath/$mainRepo"
run git reset --hard

if [ "$hasLocalRepo" = true ] && [ -d "$basePath" ]; then
    output Success "Exist cdnjs local repo, fetch objects from local branch first"
    run git fetch local
else
    output Info "Local repo not found, will grab object(s) from GitHub"
fi

output Info "Pull cdnjs main repo with rebase from origin(GitHub)"
status=`run git pull --rebase origin master`

if [ "$status" = "Current branch master is up to date." ]; then
    msg="Cdnjs main reop is up to date, no need to rebuild";
    output Info "$msg" gitter
else
    msg="Make sure npm package dependencies, do npm install && npm update"
    output Info "$msg"
    run npm install
    run npm update
    msg="Run npm test before building the meta data/artifacts"
    output Info "$msg"
    run npm test -- --silent
    msg="Reset and checkout website repository to meta branch"
    output Info "$msg"
    run git -C $basePath/$webRepo reset --hard
    run git -C $basePath/$webRepo checkout meta
    msg="Rebuild meta data phase 1"
    output Info "$msg" gitter
    run node build/packages.json.js

    msg="Rebuild meta data phase 2"
    output Info "$msg" gitter
    run cd $basePath/$webRepo
    run node update.js

    msg="Commit meta data update in website repo"
    output Info "$msg" gitter
    for file in atom.xml packages.min.json rss.xml sitemap.xml
    do
        run git add public/$file
    done
    run git commit --message="meta data"

    updateMeta=true
fi

output Info "Change directory into website repo"
run cd $basePath/$webRepo

output Info "Reset repository to prevent unstaged changes break the build"
run git reset --hard

output Info "Checkout to master branch"
run git checkout master

output Info "Pull website repo with rebase from origin(Repo)"
webstatus=`run git pull --rebase origin master`
if [ ! "$webstatus" = "Current branch master is up to date." ]; then
    updateRepo=true
fi

output Info "Update/Initial submodule under website repo" gitter
run git submodule update --init

msg="Make sure npm package dependencies, do npm install & npm update"
output Info "$msg" gitter
run npm install
run npm update

msg="Rebase website's meta branch on master"
output Info "$msg" gitter
webstatus=`run git rebase master meta`
if [ ! "$webstatus" = "Current branch meta is up to date." ]; then
    updateRepo=true
fi

if [ "$updateMeta" = true ]; then
    msg="Now push and deploy website & api"
    output Info "$msg" gitter
    for remote in heroku heroku2
    do
        git push $remote meta:master -f || error "Failed deployment on $remote ..."
    done
    if [ "$pushMetaOnGitHub" = true ]; then
        run git push origin meta -f
    fi
    if [ ! -z "$githubToken" ] && [ ! -z "$algoliaToken" ]; then
        msg="Now rebuild algolia search index"
        output Info "$msg" gitter
        run git checkout meta
        export GITHUB_OAUTH_TOKEN=$githubToken
        export ALGOLIA_API_KEY=$algoliaToken
        run node reindex.js
        run git add GitHub.repos.meta.json
        run git commit --amend --no-edit
        unset GITHUB_OAUTH_TOKEN
        unset ALGOLIA_API_KEY
    else
        error "Missing GitHub or algolia api key, cannot rebuild the searching index"
    fi
elif [ "$updateRepo" = true ]; then
    msg="Now push and deploy website only, no need to deploy api due to meta data no update"
    output Info "$msg" gitter
    run git push heroku meta:master -f
    if [ "$pushMetaOnGitHub" = true ]; then
        run git push origin meta -f
    fi
else
    msg="Didn't update anything, no need to push or deploy."
    output Info "$msg" gitter
fi

msg="Update finished."
output Success "$msg" gitter
output Info "End date time: `date`"
