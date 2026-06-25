#!/bin/bash
set -euo pipefail
REPO="${1:?Usage: $0 <repo-name> [required.txt]}"
NEXUS_URL="${NEXUS_URL:-http://incetks2000:8081}"
REQUIRED_FILE="${2:-required.txt}"
CURL_AUTH=()
CONT_TOKEN=""
ALL_URLS=$(mktemp)
trap 'rm -f "$ALL_URLS"' EXIT
while :; do
  url="$NEXUS_URL/service/rest/v1/components?repository=$REPO"
  [ -n "$CONT_TOKEN" ] && url="$url&continuationToken=$CONT_TOKEN"
  RESP=$(curl -sf "${CURL_AUTH[@]}" "$url")
  echo "$RESP" | jq -r '
    .items[]
    | . as $c
    | $c.assets[]
    | select(.path | test("\\.tgz$"))
    | (.downloadUrl // empty)
  ' >> "$ALL_URLS"
  # fallback if downloadUrl empty
  echo "$RESP" | jq -r '
    .items[]
    | . as $c
    | $c.assets[]
    | select(.path | test("\\.tgz$"))
    | select(.downloadUrl == null)
    | "'"$NEXUS_URL"'/repository/'"$REPO"'/" + .path
  ' >> "$ALL_URLS"
  CONT_TOKEN=$(echo "$RESP" | jq -r '.continuationToken // empty')
  [ -z "$CONT_TOKEN" ] && break
done
if [ -f "$REQUIRED_FILE" ]; then
  while read -r name; do
    name=$(echo "$name" | tr -d '[:space:]')
    [ -z "$name" ] && continue
    match=$(grep -F "/${name}.tgz" "$ALL_URLS" | head -1)
    if [ -n "$match" ]; then
      echo "$match"
    else
      echo "MISSING: $name (repo=$REPO)" >&2
    fi
  done < "$REQUIRED_FILE"
else

  sort -u "$ALL_URLS"
fi


