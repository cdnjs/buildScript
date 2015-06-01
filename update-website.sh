#!/bin/bash

githubToken=""
algoliaToken=""

basePath="/home/user/cdnjs"
mainRepo="cdnjsmaster"
webRepo="new-website"
hasLocalRepo=true
updateMeta=false
updateRepoo=false

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

if [ "$hasLocalRepo" = true ] && [ -d "$basePath" ]; then
    Green "Exist cdnjs local repo, fetch objects from local branch first"
    git fetch local
else
    Cyan "Local repo not found, will grab object(s) from GitHub"
fi

Cyan "Pull cdnjs main repo with rebase from origin(GitHub)"
status=`git pull --rebase origin master`

if [ "$status" = "Current branch master is up to date." ]; then
    Cyan "Cdnjs main reop is up to date, no need to rebuild";
else
    Green "Rebuild meta data phase 1"
    git -C $basePath/$webRepo checkout meta
    node build/packages.json.js

    Green "Rebuild meta data phase 2"
    cd $basePath/$webRepo
    node update.js

    Green "Commit meta data update in website repo"
    for file in atom.xml packages.min.json rss.xml sitemap.xml
    do
        git -C $basePath/$webRepo add public/$file
    done
    git -C $basePath/$webRepo commit --message="meta data"

    updateMeta=true
fi

Cyan "Change directory into website repo and checkout to master branch"
cd $basePath/$webRepo
git checkout master

Cyan "Pull website repo with rebase from origin(Repo)"
webstatus=`git pull --rebase`
if [ "$webstatus" = "Current branch master is up to date." ]; then
    Cyan "Website master branch up to date, no need to update meta branch"
else
    Green "Rebase website's meta branch on master"
    git rebase master meta
    updateRepo=true
fi

if [ "$updateMeta" = true ]; then
    Green "Now push and deploy website & api"
    git push origin meta -f
    git push heroku meta:master -f
    git push heroku2 meta:master -f
    Green "Now rebuild algolia search index"
    git checkout meta
    if [ -z "$githubToken" ] || [ -z "$algoliaToken" ]; then
        GITHUB_OAUTH_TOKEN=$githubToken ALGOLIA_API_KEY=$algoliaToken node reindex.js
    else
        Red "Missing GitHub or algolia api key, cannot rebuild the searching index"
    fi
elif [ "$updateRepo" = true ]; then
    Green "Now push and deploy website only, no need to deploy api due to meta data no update"
    git push heroku meta:master -f
else
    Cyan "Didn't update anything, no need to push or deploy."
fi
