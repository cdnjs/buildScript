#!/usr/bin/env bash

. config.sh

apiUrl='https://api.github.com/repos/cdnjs/cdnjs/issues'

IssueTitle="[Build failed] Got error while building meta data/artifact"
IssueAssignee="PeterDaveHello"
IssueLabels='["Bug - High Priority"]'
IssueContent="`sed ':a;N;$!ba;s/\n/\\\n/g' issueTemplate`"

Issue="{ \"title\": \"$IssueTitle\", \"body\": \"$IssueContent\", \"assignee\": \"$IssueAssignee\", \"labels\": $IssueLabels }"

./update-website.sh || curl --silent -H "Authorization: token $githubToken" -d "$Issue" "$apiUrl" > /dev/null
