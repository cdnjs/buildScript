#!/bin/bash

githubToken=""
algoliaToken=""
gitterHook=""

basePath="/home/user/cdnjs"
mainRepo="cdnjsmaster"
webRepo="new-website"
hasLocalRepo=true
updateMeta=false
updateRepo=false

pth="$(dirname $(readlink -f $0))"
. "$pth/colorOutput.sh"

if [ ! -d "$basePath/$mainRepo" ]; then
    Red "Main repo not found, exit now."
    exit
fi

if [ ! -d "$basePath/$webRepo" ]; then
    Red "website repo not found, exit now."
    exit
fi

cd "$basePath/$mainRepo"

function gitter()
{
    curl --silent -d message="[cronjob] $1" "$gitterHook" > /dev/null
}

gitter "Start website/api/index building process on PeterDaveHello's server ..."

if [ "$hasLocalRepo" = true ] && [ -d "$basePath" ]; then
    Green "Exist cdnjs local repo, fetch objects from local branch first"
    git fetch local || Red "Error"
else
    Cyan "Local repo not found, will grab object(s) from GitHub"
fi

Cyan "Pull cdnjs main repo with rebase from origin(GitHub)"
status=`git pull --rebase origin master`

if [ "$status" = "Current branch master is up to date." ]; then
    msg="Cdnjs main reop is up to date, no need to rebuild";
    Cyan "$msg"
    gitter "$msg"
else
    msg="Rebuild meta data phase 1"
    Green "$msg"
    gitter "$msg"
    git -C $basePath/$webRepo checkout meta || Red "Error"
    node build/packages.json.js || Red "Error"

    msg="Rebuild meta data phase 2"
    Green "$msg"
    gitter "$msg"
    cd $basePath/$webRepo || Red "Error"
    node update.js || Red "Error"

    msg="Commit meta data update in website repo"
    Green "$msg"
    gitter "$msg"
    for file in atom.xml packages.min.json rss.xml sitemap.xml
    do
        git -C $basePath/$webRepo add public/$file || Red "Error"
    done
    git -C $basePath/$webRepo commit --message="meta data" || Red "Error"

    updateMeta=true
fi

Cyan "Change directory into website repo and checkout to master branch"
cd $basePath/$webRepo
git checkout master || Red "Error"

Cyan "Pull website repo with rebase from origin(Repo)"
webstatus=`git pull --rebase`
if [ "$webstatus" = "Current branch master is up to date." ]; then
    msg="Website master branch up to date, no need to update meta branch's base"
    Cyan "$msg"
    gitter "$msg"
else
    msg="Rebase website's meta branch on master"
    Green "$msg"
    gitter "$msg"
    git rebase master meta || Red "Error"
    updateRepo=true
fi

if [ "$updateMeta" = true ]; then
    msg="Now push and deploy website & api"
    Green "$msg"
    gitter "$msg"
    for remote in heroku heroku2
    do
        git push $remote meta:master -f
        if [ ! $? -eq 0 ]; then
            msg="Failed deployment on $remote ..."
            Red "$msg"
            gitter "$msg"
        fi
    done
    git push origin meta -f || Red "Error"
    git checkout meta || Red "Error"
    if [ ! -z "$githubToken" ] && [ ! -z "$algoliaToken" ]; then
        msg="Now rebuild algolia search index"
        Green "$msg"
        gitter "$msg"
        GITHUB_OAUTH_TOKEN=$githubToken ALGOLIA_API_KEY=$algoliaToken node reindex.js  || Red "Error"
    else
        Red "Missing GitHub or algolia api key, cannot rebuild the searching index"
    fi
elif [ "$updateRepo" = true ]; then
    msg="Now push and deploy website only, no need to deploy api due to meta data no update"
    Green "$msg"
    gitter "$msg"
    git push heroku meta:master -f || Red "Error"
else
    msg="Didn't update anything, no need to push or deploy."
    Cyan "$msg"
    gitter "$msg"
fi

msg="Update finished."
Cyan "$msg"
gitter "$msg"
