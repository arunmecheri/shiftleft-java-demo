#!/bin/sh

set -e

GITHUB_BRANCH=${GITHUB_REF##*/}
GITHUB_PROJECT=${GITHUB_REPO##*/}
PULL_REQUEST=$(curl "https://api.github.com/repos/$GITHUB_REPO/pulls?state=open" \
  -H "Authorization: Bearer $GITHUB_TOKEN" | jq ".[] | select(.head.sha==\"$GITHUB_SHA\") | .number")

echo "$PULL_REQUEST"

COMMENT_BODY='{"body":""}'
COMMENT_BODY=$(echo "$COMMENT_BODY" | jq '.body += "<img height=20 src=\"https://www.shiftleft.io/static/images/ShiftLeft_logo_white.svg\"/> — NG SAST Analysis Findings\\n===\\n\\n### New Findings\\n"')

NEW_FINDINGS=$(curl -H "Authorization: Bearer $SHIFTLEFT_API_TOKEN" "https://www.shiftleft.io/api/v4/orgs/$SHIFTLEFT_ORG_ID/apps/$GITHUB_PROJECT/scans/compare?source=tag.branch=master&target=tag.branch=$GITHUB_BRANCH" | jq -c -r '.response.new | .? | .[] | "* [ID " + .id + "](https://www.shiftleft.io/findingDetail/" + .app + "/" + .id + "): " + "["+.severity+"] " + .title')

COMMENT_BODY=$(echo "$COMMENT_BODY" | jq ".body += \"$NEW_FINDINGS\"")
echo $COMMENT_BODY

curl -s -XPOST "https://api.github.com/repos/$GITHUB_REPO/issues/$PULL_REQUEST/comments" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$COMMENT_BODY"

curl -s -XPOST "https://api.github.com/repos/$GITHUB_REPO/statuses/$GITHUB_SHA" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"state\": \"success\", \"context\": \"Vulnerability analysis\", \"target_url\": \"https://www.shiftleft.io/violationlist/$GITHUB_PROJECT?apps=$GITHUB_PROJECT&isApp=1\"}"

${GITHUB_WORKSPACE}/sl check-analysis --app "$GITHUB_PROJECT" --source 'tag.branch=master' --target "tag.branch=$GITHUB_BRANCH"
