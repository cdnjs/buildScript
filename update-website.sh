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

echo "Pull cdnjs main repo with rebase from origin(GitHub)"
status=`git pull --rebase origin master`

if [ "$status" = "Current branch master is up to date." ]; then
    echo "Cdnjs main reop is up to date, no need to rebuild";
else
    echo "Rebuild meta data phase 1"
    git -C $basePath/$webRepo checkout meta
    node build/packages.json.js

    echo "Rebuild meta data phase 2"
    cd $basePath/$webRepo
    node update.js

    echo "Commit meta data upadte in website repo"
    git -C $basePath/$webRepo commit --amend --no-edit

    update=true
fi

echo "Change directory into website repo and checkout to master branch"
cd $basePath/$webRepo
git checkout master

echo "Pull website repo with rebase from origin(Repo)"
webstatus=`git -C $basePath/$webRepo pull --rebase`
if [ "$webstatus" = "Current branch master is up to date." ]; then
    echo "Website master branch up to date, no need to update meta branch"
else
    echo "Rebase website's meta branch on master"
    git rebase master meta
    update=true
fi

if [ "$update" = true ]; then
    echo "Now push and reploy website"
    git push origin meta -f
    git push heroku2 meta:master -f
    git push heroku meta:master -f
    echo "Now rebuild algolia search index"
    GITHUB_OAUTH_TOKEN=$githubToken ALGOLIA_API_KEY=$algoliaToken node reindex.js
else
    echo "Didn't update anything, no need to push or deploy."
fi
