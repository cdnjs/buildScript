#!/usr/bin/env bash

set -e

pth="$(dirname $(readlink -f $0))"

. "$pth/config.sh"

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
    output Warn "$MSG" gitter
    exit 1
}

function run()
{
    "$@" || error "Got error while running command: '$@'"
}

if [ ! -d "$basePath/$mainRepo" ]; then
    error "Main repo not found, exit now."
fi

if [ ! -d "$basePath/$webRepo" ]; then
    error "website repo not found, exit now."
fi

cd "$basePath/$mainRepo"

output Info "Start website/api/index building process on PeterDaveHello's server ..." gitter

if [ "$hasLocalRepo" = true ] && [ -d "$basePath" ]; then
    output Success "Exist cdnjs local repo, fetch objects from local branch first"
    run git fetch local
else
    output Info "Local repo not found, will grab object(s) from GitHub"
fi

output Info "Pull cdnjs main repo with rebase from origin(GitHub)"
status=`git pull --rebase origin master`

if [ "$status" = "Current branch master is up to date." ]; then
    msg="Cdnjs main reop is up to date, no need to rebuild";
    output Info "$msg" gitter
else
    msg="Make sure npm package dependencies, do npm install"
    output Success "$msg"
    run npm install
    msg="Rebuild meta data phase 1"
    output Success "$msg" gitter
    run git -C $basePath/$webRepo checkout meta
    run node build/packages.json.js

    msg="Rebuild meta data phase 2"
    output Success "$msg" gitter
    run cd $basePath/$webRepo
    run node update.js

    msg="Commit meta data update in website repo"
    output Success "$msg" gitter
    for file in atom.xml packages.min.json rss.xml sitemap.xml
    do
        run git -C $basePath/$webRepo add public/$file
    done
    run git -C $basePath/$webRepo commit --message="meta data"

    updateMeta=true
fi

output Info "Change directory into website repo and checkout to master branch"
cd $basePath/$webRepo
run git checkout master

output Info "Pull website repo with rebase from origin(Repo)"
webstatus=`git pull --rebase`
if [ "$webstatus" = "Current branch master is up to date." ]; then
    msg="Website master branch up to date, no need to update meta branch's base"
    output Info "$msg" gitter
else
    msg="Make sure npm package dependencies, do npm install"
    output Success "$msg" gitter
    run npm install
    msg="Rebase website's meta branch on master"
    output Success "$msg" gitter
    run git rebase master meta
    updateRepo=true
fi

if [ "$updateMeta" = true ]; then
    msg="Now push and deploy website & api"
    output Success "$msg" gitter
    for remote in heroku heroku2
    do
        git push $remote meta:master -f || error "Failed deployment on $remote ..."
    done
    if [ "$pushMetaOnGitHub" = true ]; then
        run git push origin meta -f
    fi
    if [ ! -z "$githubToken" ] && [ ! -z "$algoliaToken" ]; then
        msg="Now rebuild algolia search index"
        output Success "$msg" gitter
        run git checkout meta
        export GITHUB_OAUTH_TOKEN=$githubToken
        export ALGOLIA_API_KEY=$algoliaToken
        run node reindex.js
        unset GITHUB_OAUTH_TOKEN
        unset ALGOLIA_API_KEY
    else
        error "Missing GitHub or algolia api key, cannot rebuild the searching index"
    fi
elif [ "$updateRepo" = true ]; then
    msg="Now push and deploy website only, no need to deploy api due to meta data no update"
    output Success "$msg" gitter
    run git push heroku meta:master -f
    if [ "$pushMetaOnGitHub" = true ]; then
        run git push origin meta -f
    fi
else
    msg="Didn't update anything, no need to push or deploy."
    output Info "$msg" gitter
fi

msg="Update finished."
output Info "$msg" gitter
