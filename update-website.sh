#!/usr/bin/env bash

set -e

. config.sh

pth="$(dirname $(readlink -f $0))"
. "$pth/colorEcho/dist/ColorEcho.bash"

if [ ! -d "$basePath/$mainRepo" ]; then
    echo.Red "Main repo not found, exit now."
    exit 1
fi

if [ ! -d "$basePath/$webRepo" ]; then
    echo.Red "website repo not found, exit now."
    exit 1
fi

cd "$basePath/$mainRepo"

function gitter()
{
    curl --silent -d message="[cronjob] $1" "$gitterHook" > /dev/null
}

gitter "Start website/api/index building process on PeterDaveHello's server ..."

if [ "$hasLocalRepo" = true ] && [ -d "$basePath" ]; then
    echo.Green "Exist cdnjs local repo, fetch objects from local branch first"
    git fetch local || echo.Red "Error"
else
    echo.Cyan "Local repo not found, will grab object(s) from GitHub"
fi

echo.Cyan "Pull cdnjs main repo with rebase from origin(GitHub)"
status=`git pull --rebase origin master`

if [ "$status" = "Current branch master is up to date." ]; then
    msg="Cdnjs main reop is up to date, no need to rebuild";
    echo.Cyan "$msg"
    gitter "$msg"
else
    msg="Make sure npm package dependencies, do npm install"
    echo.Green "$msg"
    gitter "$msg"
    npm install
    msg="Rebuild meta data phase 1"
    echo.Green "$msg"
    gitter "$msg"
    git -C $basePath/$webRepo checkout meta || echo.Red "Error"
    node build/packages.json.js || echo.Red "Error"

    msg="Rebuild meta data phase 2"
    echo.Green "$msg"
    gitter "$msg"
    cd $basePath/$webRepo || echo.Red "Error"
    node update.js || echo.Red "Error"

    msg="Commit meta data update in website repo"
    echo.Green "$msg"
    gitter "$msg"
    for file in atom.xml packages.min.json rss.xml sitemap.xml
    do
        git -C $basePath/$webRepo add public/$file || echo.Red "Error"
    done
    git -C $basePath/$webRepo commit --message="meta data" || echo.Red "Error"

    updateMeta=true
fi

echo.Cyan "Change directory into website repo and checkout to master branch"
cd $basePath/$webRepo
git checkout master || echo.Red "Error"

echo.Cyan "Pull website repo with rebase from origin(Repo)"
webstatus=`git pull --rebase`
if [ "$webstatus" = "Current branch master is up to date." ]; then
    msg="Website master branch up to date, no need to update meta branch's base"
    echo.Cyan "$msg"
    gitter "$msg"
else
    msg="Make sure npm package dependencies, do npm install"
    echo.Green "$msg"
    npm install
    msg="Rebase website's meta branch on master"
    echo.Green "$msg"
    gitter "$msg"
    git rebase master meta || echo.Red "Error"
    updateRepo=true
fi

if [ "$updateMeta" = true ]; then
    msg="Now push and deploy website & api"
    echo.Green "$msg"
    gitter "$msg"
    for remote in heroku heroku2
    do
        git push $remote meta:master -f
        if [ ! $? -eq 0 ]; then
            msg="Failed deployment on $remote ..."
            echo.Red "$msg"
            gitter "$msg"
        fi
    done
    git push origin meta -f || echo.Red "Error"
    git checkout meta || echo.Red "Error"
    if [ ! -z "$githubToken" ] && [ ! -z "$algoliaToken" ]; then
        msg="Now rebuild algolia search index"
        echo.Green "$msg"
        gitter "$msg"
        GITHUB_OAUTH_TOKEN=$githubToken ALGOLIA_API_KEY=$algoliaToken node reindex.js  || echo.Red "Error"
    else
        echo.Red "Missing GitHub or algolia api key, cannot rebuild the searching index"
    fi
elif [ "$updateRepo" = true ]; then
    msg="Now push and deploy website only, no need to deploy api due to meta data no update"
    echo.Green "$msg"
    gitter "$msg"
    git push heroku meta:master -f || echo.Red "Error"
else
    msg="Didn't update anything, no need to push or deploy."
    echo.Cyan "$msg"
    gitter "$msg"
fi

msg="Update finished."
echo.Cyan "$msg"
gitter "$msg"
