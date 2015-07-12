#!/usr/bin/env bash

pth="$(dirname $(readlink -f $0))"
. "$pth/config.sh"

apiUrl='https://api.github.com/repos/cdnjs/cdnjs/issues'

IssueTitle="[Build failed] Got error while building meta data/artifact"
IssueAssignee="PeterDaveHello"
IssueLabels='["Bug - High Priority"]'
IssueContent="`sed ':a;N;$!ba;s/\n/\\\n/g' $pth/issueTemplate`"

Issue="{ \"title\": \"$IssueTitle\", \"body\": \"$IssueContent\", \"assignee\": \"$IssueAssignee\", \"labels\": $IssueLabels }"

"$pth/update-website.sh" > /dev/null || curl --silent -H "Authorization: token $githubToken" -d "$Issue" "$apiUrl" > /dev/null
