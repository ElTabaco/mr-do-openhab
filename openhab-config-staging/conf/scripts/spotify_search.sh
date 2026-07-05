#!/bin/sh
QUERY="$1"
TOKEN=$(curl -sf -u egg:egg12345 http://localhost:8080/rest/items/spotifyAccessToken 2>/dev/null | grep -o '\"state\":\"[^\" ]*\"' | head -1 | sed 's/\"state\":\"//;s/\"//')

if [ -z "$QUERY" ] || [ ${#QUERY} -lt 2 ]; then echo "Enter search term"; exit 0; fi
if [ -z "$TOKEN" ] || [ "$TOKEN" = "NULL" ]; then echo "No token"; exit 0; fi

ENCODED=$(echo "$QUERY" | sed 's/ /%20/g; s/&/%26/g')
RESULT=$(curl -sf -H "Authorization: Bearer $TOKEN" "https://api.spotify.com/v1/search?q=$ENCODED&type=track&limit=8")

if [ $? -ne 0 ]; then echo "Search failed"; exit 0; fi

echo "$RESULT" | sed 's/},{/}\n{/g' | grep 'spotify:track' | while IFS= read -r track; do
    NAME=$(echo "$track" | grep -o '\"name\":\"[^\"]*\"' | head -1 | sed 's/\"name\":\"//;s/\"//')
    URI=$(echo "$track" | grep -o '\"uri\":\"spotify:track:[^\"]*\"' | head -1 | sed 's/\"uri\":\"//;s/\"//')
    echo "$NAME | $URI"
done
