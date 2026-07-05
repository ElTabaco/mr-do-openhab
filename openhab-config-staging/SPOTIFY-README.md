# Spotify Integration

## Architecture

- **Binding**: `binding-spotify` v5.1.4 (installed via REST API + addons.cfg)
- **Bridge Thing**: `spotify:player:user1` (created via REST API, stored in jsondb)
- **OAuth2**: Authorized via SSH tunnel using `http://127.0.0.1:8080/connectspotify`
- **UI Page**: "Spotify" MainUI page (created via REST API, stored in jsondb)
- **Search**: Shell script (`spotify_search.sh`) + DSL rule using `executeCommandLine`

## Files in this repo (reference-only, NOT auto-deployed)

⚠️ These files are **staging/reference copies**. ArgoCD manages K8s manifests only
(`kubernetes/openhab/`), NOT `conf/` files. The live config lives in jsondb on NFS.

- `conf/things/spotify.things` — bridge definition (PLACEHOLDER credentials)
- `conf/items/spotify.items` — item definitions with channel links
- `conf/ui/spotify_page.yaml` — exported MainUI page layout
- `conf/scripts/spotify_search.sh` — search script (pure shell + curl)
- `conf/persistence/mapdb.persist` — MapDB restoreOnStartup for spotify items
- `conf/services/addons.cfg` — includes `binding = spotify`

## Re-Authorization Procedure

If the Spotify bridge goes OFFLINE (token expired or revoked):

1. Start SSH tunnel from your laptop:
   ```bash
   ssh -L 8080:192.168.0.22:80 mr@192.168.0.200
   ```

2. Open in browser: http://127.0.0.1:8080/connectspotify

3. Click "Authorize Player" → log into Spotify → approve

4. Bridge should go ONLINE within seconds.

## Spotify Developer App

- Dashboard: https://developer.spotify.com/dashboard
- Redirect URI: `http://127.0.0.1:8080/connectspotify`
- Required scopes (set automatically by binding):
  - `user-read-playback-state`
  - `user-modify-playback-state`
  - `playlist-read-private`
  - `playlist-read-collaborative`

## Config Parameters

| Parameter | Value | Notes |
|-----------|-------|-------|
| refreshPeriod | 30s | Polling interval (reduced from default 10s) |
| Binding type | cloud | Outbound HTTPS to api.spotify.com only |
| Premium required | Yes | Playback control needs Premium account |
