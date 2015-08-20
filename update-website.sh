#!/usr/bin/env bash

set -e

pth="$(dirname $(readlink -f $0))"

. "$pth/config.sh"

rm -f $logFile

. "$pth/colorEcho/dist/ColorEcho.bash"

function output()
{
    echo "[$1] $2" >> $logFile
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
        curl --silent -d message="[cronjob] $2" "$gitterHook" > /dev/null
    fi
}

if [ ! -d "$basePath/$mainRepo" ]; then
    output Warn "Main repo not found, exit now." gitter
    exit 1
fi

if [ ! -d "$basePath/$webRepo" ]; then
    output Warn "website repo not found, exit now." gitter
    exit 1
fi

cd "$basePath/$mainRepo"

output Info "Start website/api/index building process on PeterDaveHello's server ..." gitter

if [ "$hasLocalRepo" = true ] && [ -d "$basePath" ]; then
    output Success "Exist cdnjs local repo, fetch objects from local branch first"
    git fetch local || output Warn "Error" gitter
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
    npm install
    msg="Rebuild meta data phase 1"
    output Success "$msg" gitter
    git -C $basePath/$webRepo checkout meta || output Warn "Error" gitter
    node build/packages.json.js || output Warn "Error" gitter

    msg="Rebuild meta data phase 2"
    output Success "$msg" gitter
    cd $basePath/$webRepo || output Warn "Error" gitter
    node update.js || output Warn "Error" gitter

    msg="Commit meta data update in website repo"
    output Success "$msg" gitter
    for file in atom.xml packages.min.json rss.xml sitemap.xml
    do
        git -C $basePath/$webRepo add public/$file || output Warn "Error" gitter
    done
    git -C $basePath/$webRepo commit --message="meta data" || output Warn "Error" gitter

    updateMeta=true
fi

output Info "Change directory into website repo and checkout to master branch"
cd $basePath/$webRepo
git checkout master || output Warn "Error" gitter

output Info "Pull website repo with rebase from origin(Repo)"
webstatus=`git pull --rebase`
if [ "$webstatus" = "Current branch master is up to date." ]; then
    msg="Website master branch up to date, no need to update meta branch's base"
    output Info "$msg" gitter
else
    msg="Make sure npm package dependencies, do npm install"
    output Success "$msg" gitter
    npm install
    msg="Rebase website's meta branch on master"
    output Success "$msg" gitter
    git rebase master meta || output Warn "Error" gitter
    updateRepo=true
fi

if [ "$updateMeta" = true ]; then
    msg="Now push and deploy website & api"
    output Success "$msg" gitter
    for remote in heroku heroku2
    do
        git push $remote meta:master -f
        if [ ! $? -eq 0 ]; then
            msg="Failed deployment on $remote ..."
            output Warn "$msg" gitter
        fi
    done
    git push origin meta -f || output Warn "Error" gitter
    git checkout meta || output Warn "Error" gitter
    if [ ! -z "$githubToken" ] && [ ! -z "$algoliaToken" ]; then
        msg="Now rebuild algolia search index"
        output Success "$msg" gitter
        GITHUB_OAUTH_TOKEN=$githubToken ALGOLIA_API_KEY=$algoliaToken node reindex.js  || output Warn "Error" gitter
    else
        output Warn "Missing GitHub or algolia api key, cannot rebuild the searching index"
    fi
elif [ "$updateRepo" = true ]; then
    msg="Now push and deploy website only, no need to deploy api due to meta data no update"
    output Success "$msg" gitter
    git push heroku meta:master -f || output Warn "Error" gitter
    if [ "$pushMetaOnGitHub" = true ]; then
        git push origin meta -f || output Warn "Error" gitter
    fi
else
    msg="Didn't update anything, no need to push or deploy."
    output Info "$msg" gitter
fi

msg="Update finished."
output Info "$msg" gitter
