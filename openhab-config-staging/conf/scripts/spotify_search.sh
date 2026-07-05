#!/bin/sh
QUERY="$1"
TOKEN=$(curl -sf -u egg:egg12345 http://localhost:8080/rest/items/spotifyAccessToken 2>/dev/null | sed 's/.*"state":"//; s/".*//')

if [ -z "$QUERY" ] || [ ${#QUERY} -lt 2 ]; then echo "Enter search term"; exit 0; fi
if [ -z "$TOKEN" ] || [ "$TOKEN" = "NULL" ]; then echo "No token"; exit 0; fi

ENCODED=$(echo "$QUERY" | sed 's/ /%20/g; s/&/%26/g')
RESULT=$(curl -sf -H "Authorization: Bearer $TOKEN" "https://api.spotify.com/v1/search?q=$ENCODED&type=track&limit=8")

if [ -z "$RESULT" ]; then echo "Search failed"; exit 0; fi

ARTIST=$(echo "$RESULT" | sed 's/"name":"/\n/g' | grep '"type":"artist"' | head -1 | sed 's/","type.*//' | sed 's/"//g')

echo "$RESULT" | sed 's/"name":"/\n/g' | grep 'spotify:track' | while IFS= read -r line; do
    TRACK=$(echo "$line" | sed 's/".*//')
    URI=$(echo "$line" | sed 's/.*spotify:track:/spotify:track:/' | sed 's/".*//')
    if [ -n "$TRACK" ] && [ -n "$URI" ]; then
        echo "$ARTIST - $TRACK | $URI"
    fi
done
