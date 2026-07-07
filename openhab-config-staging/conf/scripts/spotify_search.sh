#!/bin/sh
QUERY="$1"
OH="http://localhost:8080/rest"
AUTH="egg:egg12345"

TOKEN=$(curl -sf -u "$AUTH" "$OH/items/spotifyAccessToken" 2>/dev/null | jq -r '.state // empty')

if [ -z "$QUERY" ] || [ ${#QUERY} -lt 2 ]; then
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d "Enter search term" "$OH/items/spotifySearchResults/state"
    exit 0
fi

if [ -z "$TOKEN" ] || [ "$TOKEN" = "NULL" ]; then
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d "No token" "$OH/items/spotifySearchResults/state"
    exit 0
fi

ENCODED=$(echo "$QUERY" | sed 's/ /%20/g; s/&/%26/g')
RESULT=$(curl -sf -H "Authorization: Bearer $TOKEN" "https://api.spotify.com/v1/search?q=$ENCODED&type=track&limit=6")

if [ -z "$RESULT" ]; then
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d "Search failed" "$OH/items/spotifySearchResults/state"
    exit 0
fi

# Clear previous
for i in 1 2 3 4 5 6; do
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d " " "$OH/items/spotifyResult${i}Track/state"
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d " " "$OH/items/spotifyResult${i}URI/state"
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d " " "$OH/items/spotifyResult${i}Art/state"
done

# Parse with jq, write to temp file, then read line by line in main shell
echo "$RESULT" | jq -r '.tracks.items[] | "\(.artists[0].name) - \(.name)|\(.uri)|\(.album.images[0].url // "")"' > /openhab/userdata/spotify_results.txt

COUNT=0
while IFS='|' read -r title uri art; do
    COUNT=$((COUNT + 1))
    if [ $COUNT -gt 6 ]; then break; fi
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d "$title" "$OH/items/spotifyResult${COUNT}Track/state"
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d "$uri" "$OH/items/spotifyResult${COUNT}URI/state"
    curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d "$art" "$OH/items/spotifyResult${COUNT}Art/state"
done < /openhab/userdata/spotify_results.txt

curl -sf -u "$AUTH" -X PUT -H "Content-Type: text/plain" -d "${COUNT} results for: $QUERY" "$OH/items/spotifySearchResults/state"
