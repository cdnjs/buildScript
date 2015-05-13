#!/bin/sh

basePath="/home/user/cdnjs"
mainRepo="cdnjsmaster"
webRepo="new-website"
hasLocalRepo=true
update=false
githubToken=
algoliaToken=

cd "$basePath/$mainRepo"

if [ "$hasLocalRepo" = true ]; then
    echo "Exist cdnjs local repo, fetch objects from local branch first"
    git fetch local
fi

status=`git pull --rebase origin master`
if [ "$status" = "Current branch master is up to date." ]; then
    echo "Up to date, no need to rebuild";
else
    echo "Rebuild meta data phase 1"
    git -C $basePath/$webRepo checkout meta
    node build/packages.json.js

    echo "Rebuild meta data phase 2"
    cd $basePath/$webRepo
    node update.js

    echo "Commit change"
    git -C $basePath/$webRepo --amend --no-edit

    update=true
fi

cd $basePath/$webRepo
git checkout master

webstatus=`git -C $basePath/$webRepo pull --rebase`
if [ "$webstatus" = "Current branch master is up to date." ]; then
    echo "master branch up to date, no need to update meta branch"
else
    echo "Rebase meta branch on master"
    git rebase master meta
    update=true
fi

if [ "$update" = true ]; then
    git push origin meta -f
    git push heroku2 meta:master -f
    git push heroku meta:master -f
    GITHUB_OAUTH_TOKEN=$githubToken ALGOLIA_API_KEY=$algoliaToken node reindex.js
fi
