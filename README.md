# mr-do-openhab

[openHAB](https://www.openhab.org/) home automation on Kubernetes (k3s), deployed via ArgoCD GitOps.

Two **independent** applications, each with its own ArgoCD Application and Service:

- **openHAB 5.2.2**: automation runtime (web UI, rules, things, items)
- **Mosquitto 2.1.2**: MQTT broker (standalone, reusable for other apps)

## Architecture

```
ArgoCD
  ├── Application: mr-do-openhab      → kubernetes/openhab/
  │     ├── Deployment (openhab/openhab:5.2.2-alpine, user 9001)
  │     ├── Service (LoadBalancer 192.168.0.22)
  │     ├── PV + PVC (4 GiB NFS)
  │     └── mounts: /openhab/conf/* per directory, /openhab/userdata complete
  │
  └── Application: mqtt  → kubernetes/mqtt/
        ├── Deployment (eclipse-mosquitto:2.1.2-alpine, user 1883)
        ├── ConfigMap (mosquitto.conf)
        ├── Service (LoadBalancer 192.168.0.23)
        └── dedicated PV + PVC (1 GiB NFS, separate path)
```

Each app has its own PV and PVC. They live on the same NFS server but use
different paths (`/srv/nfs4/homes/mr/openhab` and `/srv/nfs4/homes/mr/mqtt`),
so deleting one app does NOT affect the other's data.

## Deployment

### Deploy openHAB

```bash
./kubernetes/openhab/apply.sh
```

### Deploy MQTT (standalone)

```bash
./kubernetes/mqtt/apply.sh
```

### Tear down

```bash
./kubernetes/openhab/delete.sh   # type 'yes' to confirm
./kubernetes/mqtt/delete.sh       # type 'yes' to confirm
```

### Manual sync (force ArgoCD refresh)

```bash
kubectl annotate application mr-do-openhab -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application mqtt          -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

## Configuration reference

### ArgoCD Applications

| Setting | `mr-do-openhab` | `mqtt` |
|---------|-----------------|--------|
| Manifest | `kubernetes/openhab/app.yaml` | `kubernetes/mqtt/app.yaml` |
| Namespace (Application) | `argocd` | `argocd` |
| Project | `default` | `default` |
| Repository | `https://github.com/ElTabaco/mr-do-openhab.git` | same |
| Target revision | `main` | `main` |
| Path | `kubernetes/openhab` | `kubernetes/mqtt` |
| Destination | `https://kubernetes.default.svc`, namespace `mr-do-openhab` | same |
| Sync policy | automated, `prune: true`, `selfHeal: true` | same |
| Sync options | `CreateNamespace=true` | same |
| Per-resource sync options | Deployment `mr-do-openhab`: `ServerSideApply=true` (annotation `argocd.argoproj.io/sync-options`) | none |
| Ignored differences | Service `/status` (written by MetalLB) | same |

The `mr-do-openhab` Application also manages its own Application object, so changes
to `app.yaml` are applied by ArgoCD after merge.

ArgoCD applies the openHAB Deployment with server-side apply. With the default
client-side apply, a field that is deleted from `deployment.yml` stays in the cluster
when the live object has no matching `last-applied-configuration` entry. ArgoCD does
not report such leftovers as a difference, so the application still shows `Synced`.
This happened after the userdata mount change: the old `ensure-files` init container
and eight old `/openhab/userdata/*` mounts stayed in the live Deployment. With
server-side apply, the field manager `argocd-controller` removes every field it owns
that is no longer in Git.

### openHAB Deployment (`kubernetes/openhab/deployment.yml`)

| Setting | Value |
|---------|-------|
| Name / namespace / label | `mr-do-openhab` / `mr-do-openhab` / `app: mr-do-openhab` |
| Annotation | `argocd.argoproj.io/sync-options: ServerSideApply=true` (see ArgoCD Applications) |
| Image | `openhab/openhab:5.2.2-alpine` |
| Replicas | `1` |
| Update strategy | `Recreate` (one openHAB instance may own the data at a time) |
| Revision history | `10` |
| Pod `securityContext` | `fsGroup: 9001` |
| Process user | The entrypoint starts as root (time zone, volume permissions, userdata upgrade), then runs openHAB as user/group `openhab` (UID/GID `9001`) via `su-exec` |

**Container ports**

| Port | Protocol | Purpose |
|------|----------|---------|
| 8080 | TCP | Web UI / REST API (HTTP) |
| 8443 | TCP | Web UI / REST API (HTTPS) |
| 5683 | UDP | Shelly CoIoT (CoAP) peer |
| 5684 | TCP | CoAP secure |

**Environment variables set by the manifest**

| Variable | Value | Purpose |
|----------|-------|---------|
| `TZ` | `Europe/Berlin` | Container/OS time zone (set by the entrypoint) |
| `EXTRA_JAVA_OPTS` | `-Duser.timezone=Europe/Berlin -XX:MaxRAMPercentage=50.0 -XX:+ExitOnOutOfMemoryError -Djdk.tls.server.enableSessionTicketExtension=false` | JVM time zone (cron rules, timestamps); max heap = 50 % of the memory limit (1 GiB); exit on heap exhaustion so Kubernetes restarts the container; no stateless TLS session tickets (the JDK sent an empty TLS 1.3 ticket that clients reject, so HTTPS on 8443 failed with TLS 1.3) |

**Environment defaults built into the image** (not overridden here)

| Variable | Default |
|----------|---------|
| `OPENHAB_HTTP_PORT` | `8080` |
| `OPENHAB_HTTPS_PORT` | `8443` |
| `OPENHAB_HOME` | `/openhab` |
| `OPENHAB_CONF` | `/openhab/conf` |
| `OPENHAB_USERDATA` | `/openhab/userdata` |
| `OPENHAB_LOGDIR` | `/openhab/userdata/logs` |
| `OPENHAB_BACKUPS` | `/openhab/userdata/backup` |
| `USER_ID` / `GROUP_ID` | `9001` / `9001` |
| `CRYPTO_POLICY` | `limited` |
| `EXTRA_SHELL_OPTS` | empty |
| `KARAF_EXEC` | `exec` |
| `LC_ALL` / `LANG` / `LANGUAGE` | `en_US.UTF-8` |

**Resources**

| | CPU | Memory |
|-|-----|--------|
| Requests | `500m` | `1Gi` (resident memory of the running JVM is about 0.9-1.0 GiB) |
| Limits | `2` | `2Gi` |

**Probes** (all `HTTP GET /` on port 8080)

| Probe | Initial delay | Period | Timeout | Failure threshold |
|-------|---------------|--------|---------|-------------------|
| startup | 30 s | 15 s | 1 s (default) | 20 (up to 5.5 min for start and upgrade) |
| readiness | - | 15 s | 5 s | 6 |
| liveness | - | 30 s | 10 s | 3 |

**Volume mounts** (all from PVC `mr-do-openhab-pvc-data`; NFS path = `/srv/nfs4/homes/mr/` + subPath)

| Container path | subPath on the volume | Content |
|----------------|----------------------|---------|
| `/openhab/conf/items` | `openhab/conf/items` | `*.items` files |
| `/openhab/conf/things` | `openhab/conf/things` | `*.things` files |
| `/openhab/conf/rules` | `openhab/conf/rules` | DSL `*.rules` files |
| `/openhab/conf/scripts` | `openhab/conf/scripts` | Scripts called by rules / exec binding |
| `/openhab/conf/sitemaps` | `openhab/conf/sitemaps` | `*.sitemap` files |
| `/openhab/conf/services` | `openhab/conf/services` | `addons.cfg`, `runtime.cfg`, `basicui.cfg`, ... |
| `/openhab/conf/persistence` | `openhab/conf/persistence` | `*.persist` files (empty: persistence is configured in the UI) |
| `/openhab/conf/transform` | `openhab/conf/transform` | `*.map` and other transformations |
| `/openhab/conf/html` | `openhab/conf/html` | Static files served under `/static` |
| `/openhab/conf/icons/classic` | `openhab/conf/icons/classic` | Custom icons |
| `/openhab/conf/automation` | `openhab/conf/automation` | Script automation files |
| `/openhab/conf/sounds` | `openhab/conf/sounds` | Sound files (alarm, doorbell, ...) |
| `/openhab/conf/misc` | `openhab/conf/misc` | `exec.whitelist` |
| `/openhab/userdata` | `openhab/userdata` | **Complete** userdata: `jsondb` (UI-managed things, items, rules, pages), `config`, `persistence` (rrd4j data), `secrets`, `openhabcloud`, `uuid`, `etc` (Karaf system files + `version.properties`), `cache`, `tmp`, `logs`, `backup` |
| `/openhab/addons` | `openhab/addons` | Manually installed add-on JARs/KARs |

The other `/openhab/conf` directories (for example `conf/tags`) come from the image.

`/openhab/userdata` must be one persistent directory:

- On start, the image entrypoint compares `userdata/etc/version.properties` with
  the image. After an image version change it writes a backup to
  `/openhab/userdata/backup/userdata-<timestamp>.tar` and runs `runtime/bin/update`.
  That script replaces the Karaf system files, clears `cache`/`tmp` and runs the JSON
  database upgrade tool. With a container-local `etc` this check never fires.
- `cache` and `tmp` survive restarts, so add-ons are not downloaded and installed on
  every start. A cache-cleared start installs add-ons while the rule engine is already
  running. The resulting bundle refresh broke UI rules with inline DSL scripts
  (`NullPointerException ... ScriptStandaloneSetup.getInjector()`, openhab-core
  issues #4813 and #5221).

### openHAB Service (`kubernetes/openhab/service.yml`)

| Setting | Value |
|---------|-------|
| Name | `mr-do-openhab-service` |
| Type | `LoadBalancer`, `loadBalancerIP: 192.168.0.22` (MetalLB) |
| Selector | `app: mr-do-openhab` |

| Name | Port | Target port | Protocol |
|------|------|-------------|----------|
| `webinterface` | 80 | 8080 | TCP |
| `https-webinterface` | 8443 | 8443 | TCP |
| `coiot-peer` | 5683 | 5683 | UDP |
| `coap-secure-port` | 5684 | 5684 | TCP |

### MQTT broker (`kubernetes/mqtt/`)

| Setting | Value |
|---------|-------|
| Deployment | `mqtt`, label `app: mqtt`, 1 replica, strategy `Recreate`, revision history `10` |
| Image | `eclipse-mosquitto:2.1.2-alpine` |
| Pod `securityContext` | `runAsNonRoot: true`, `runAsUser: 1883`, `fsGroup: 1883` |
| Container `securityContext` | `allowPrivilegeEscalation: false`, all capabilities dropped |
| Environment | `TZ=Europe/Berlin` |
| Resources | requests `50m` CPU / `64Mi`; limits `200m` CPU / `256Mi` |
| Probes | readiness TCP 1883 (delay 5 s, period 10 s); liveness TCP 1883 (delay 10 s, period 30 s) |
| Volume mounts | `/mosquitto/data` ← PVC `mqtt-pvc-data` subPath `mqtt/data`; `/mosquitto/config/mosquitto.conf` ← ConfigMap `mqtt-config` key `mosquitto.conf` |
| Service | `mqtt`, `LoadBalancer`, `loadBalancerIP: 192.168.0.23`: `mqtt` 1883/TCP, `mqtt-websockets` 9001/TCP |

`mosquitto.conf` (ConfigMap `mqtt-config`):

| Setting | Value |
|---------|-------|
| `persistence` | `true` |
| `persistence_location` | `/mosquitto/data/` |
| `autosave_interval` | `1800` (seconds) |
| `listener 1883` | MQTT, `allow_anonymous true` |
| `listener 9001` | `protocol websockets`, `allow_anonymous true` |

openHAB connects to the broker through the cluster Service name `mqtt`, port 1883
(file-defined bridge `mqtt:broker:mosquitto` in `conf/things/mqtt.things`).

## Persistent Storage

| App | PV | PVC | NFS path | Size | Access mode |
|-----|----|-----|----------|------|-------------|
| openHAB | `mr-do-openhab-pv-data` | `mr-do-openhab-pvc-data` | `/srv/nfs4/homes/mr/openhab` | 4 GiB | `ReadWriteMany` |
| MQTT | `mqtt-pv-data` | `mqtt-pvc-data` | `/srv/nfs4/homes/mr/mqtt` | 1 GiB | `ReadWriteMany` |

Both PVs use NFS server `mr0.local`, `persistentVolumeReclaimPolicy: Retain`,
`storageClassName: ""` and `volumeMode: Filesystem`. The PVCs bind by label
(`usage: mr-do-openhab-pv-data` / `usage: mqtt-pv-data`).

Layout of the openHAB volume (`/srv/nfs4/homes/mr/openhab`):

```
openhab/
├── addons/      → /openhab/addons
├── conf/        → /openhab/conf/<dir> (one mount per directory)
└── userdata/    → /openhab/userdata
```

Files on the volume are owned by UID/GID 9001 (the `openhab` user in the image).

## Upgrading openHAB

1. Check the [release notes](https://github.com/openhab/openhab-distro/releases)
   for breaking changes in the add-ons you use.
2. Change the image tag in `kubernetes/openhab/deployment.yml` (and
   `docker/docker-compose.yaml`), open a PR and merge it to `main`.
3. ArgoCD recreates the pod. The entrypoint detects the version change, saves
   `/openhab/userdata/backup/userdata-<timestamp>.tar` and runs the userdata upgrade
   (log: `/openhab/userdata/logs/update.log`). openHAB then installs the add-ons from
   `addons.cfg` into the new version. The startup probe allows up to 5.5 minutes.

Rollback: restore the previous image tag together with the `userdata` backup tar from
step 3. Downgrading the image without restoring userdata is not supported by openHAB.

openHAB 5.2.2 (security release) has three breaking changes. None applies to this
installation:

| 5.2.2 change | Status here |
|--------------|-------------|
| Sitemap `/proxy` only serves hosts in Settings → Sitemap → `allowedHosts` (empty by default) | No sitemap uses `Image`, `Video`, `Webview` or `Mapview`; `Chart` does not use `/proxy` |
| `trustedNetworks` ignores `X-Forwarded-For` | `trustedNetworks` is not set; clients use Basic Auth (`allowBasicAuth=true`) |
| `/auth` requires a same-origin `redirect_uri` and PKCE | No third-party OAuth2 clients; the openHAB UIs are not affected |

If a sitemap later shows an external image or camera stream, add its host to
`allowedHosts`.

## Installed add-ons

`conf/services/addons.cfg` defines the add-ons:

| Type | Add-ons |
|------|---------|
| `package` | `standard` |
| `binding` | `mqtt`, `shelly`, `exec` |
| `persistence` | `rrd4j`, `inmemory` |
| `ui` | `basic` |
| `misc` | `openhabcloud` |
| `transformation` | `exec`, `regex`, `jsonpath` |

## Configuration files (`openhab-config-staging/`)

`openhab-config-staging/conf/` is a reference copy of the file-based configuration on
the NFS volume (`openhab/conf/`). It is **not** deployed by ArgoCD; the live files on
NFS are the source of truth. Personal values are replaced by placeholders:

| File | Placeholder |
|------|-------------|
| `conf/scripts/mobileAlerts_REST_API.sh` | `<DEVICE_IDS>`, `<PHONE_ID>` (MobileAlerts cloud API) |
| `conf/rules/stoeckliSmocke.rules` | `<NOTIFICATION_EMAIL>`, `<CALLMEBOT_TELEGRAM_USER>` |

Things, items, rules and pages created in the UI are stored in
`userdata/jsondb` on the volume and are not part of this repository.

| File | Content |
|------|---------|
| `conf/things/mqtt.things` | MQTT bridge `mqtt:broker:mosquitto` (host `mqtt`, port `1883`, clientId `openhab`, keepAlive `60`). No topic Things: the temperature/humidity sensors report through the Shelly binding; the LoRa water-level Thing `mqtt:topic:mosquitto:lora_sb_001` is UI-managed. |
| `conf/rules/kuhStahlSensoren.rules` | Parses the MobileAlerts JSON (`KuhstahlSensoren`, exec Thing, every 400 s) into the `trocknungsanlage_*` items. A value is set to `UNDEF` when it is the MobileAlerts error code (`>= 43530`, probe not connected) or when the measurement timestamp `ts` is older than `3600` s (sensor no longer transmitting). |

### Water tank level (LoRa, UI-managed)

The ultrasonic sensor `sb_001` sends a distance reading about every 45 s (often 1-3 min when LoRa
packets are lost). The gateway `mr-lora-brocker` (client id `LORA_MQTT_Gateway`, user `mymqtt`)
publishes it to MQTT; openHAB processes it immediately:

| Element | Value |
|---------|-------|
| MQTT topic | `lora/sb_001/distace/value` (payload e.g. `710mm`; raw JSON on `lora/sb_001/raw`) |
| Thing / channel | `mqtt:topic:mosquitto:lora_sb_001:DistanceWater` (`mqtt:number`) |
| Item | `lorasb001_DistanceWater` (`Number:Length`, unit `mm`, display pattern `%.1f cm`) |
| Rule `WaterLevel` | trigger `core.ItemStateUpdateTrigger` on `lorasb001_DistanceWater` (every reading, also when the value is unchanged); computes `LiterWater = 5520 - (distance_mm * 0.1 - 25) * 40` and the alarm level `WaterAlarmLevel` (5 > 3500 l, 4 <= 3000 l, 3 <= 2500 l, 2 <= 2000 l, 1 <= 1000 l) |
| Sitemap `Wassertank` | chart of `LiterWater`, period `D`, `refresh=20000` ms (3 reloads per minute; rrd4j stores one value per minute) |
| Persistence | rrd4j, strategies `restoreOnStartup`, `everyChange`, `everyMinute` |

### Performance settings (live, not deployed from Git)

These settings live on the NFS volume (`userdata/`) or in the UI (jsondb), not in this repository.
They were set on 2026-10-08 to remove load caused by the Shelly 3EM energy meter, which changes
its values about twice per second.

| Setting | Where | Value | Reason |
|---------|-------|-------|--------|
| rrd4j persistence | UI → Settings → Persistence → rrd4j (`jsondb/org.openhab.core.persistence.PersistenceServiceConfiguration.json`) | config 1: items `*`, strategies `restoreOnStartup`, `everyMinute`; config 2: items `*` except `PhaseMeasure_P*`, `PhaseMeasure_V*`, `PhaseMeasure_A*`, `PhaseMeasure_KWH*` (group members `Phase1-3_P/_V/_A/_KWH`), the groups themselves and `PhaseSum_P`, strategy `everyChange` | rrd4j keeps one value per 60 s step anyway; storing every 3EM change caused ~40 % of the NFS write operations |
| Event log filter | `userdata/etc/log4j2.xml`, logger `openhab.event` | `<RegexFilter onMatch="DENY" onMismatch="NEUTRAL" regex="Item '(Phase[123]_(P\|V\|A\|KWH)\|PhaseSum_P\|PhaseMeasure_(P\|V\|A\|KWH))' (changed\|updated\|predicted) .*"/>` before `<AppenderRef ref="EVENT"/>` | the 3EM items were 96 % of `events.log` (~2.5 MB/h, rotation after ~2 days); now ~0.15 MB/h |
| Total power | link + rule | `PhaseSum_P` (kW) linked to `shelly:shellyem3:PhaseMeasure:device#accumulatedPower`; rule `eggSumPower-1` (copied `PhaseMeasure_P` into `PhaseSum_P` on every change) disabled | one item update instead of a group change + DSL rule run per change |
| `PhaseMeasure_A` | item | group base type `Number:ElectricCurrent`, function `SUM` | was `Number:ElectricPotential` → state always `UNDEF` |
| Sitemap chart refresh | sitemaps `Milchtank`, `redSpresso` / `Wassertank` | `refresh=3000` (20 reloads/min) / `refresh=20000` (3 reloads/min) | `refresh` is in milliseconds; `1` made Basic UI reload the chart image every 100 ms per chart and open browser |

Notes:

- openHAB 5.2.2 cannot reload `log4j2.xml` at runtime (pax-logging 2.3.3 logs
  `NoClassDefFoundError: org/apache/logging/log4j/simple/internal/SimpleProvider` every 10 s).
  After editing it, restart the pod (`kubectl delete pod -n mr-do-openhab -l app=mr-do-openhab`).
- An openHAB upgrade can replace `userdata/etc/log4j2.xml` with the default (entries `DEFAULT;…log4j2.xml`
  in `runtime/bin/update.lst`). After an upgrade check that the filter is still there.
- The 3EM values are still visible in the UI and stored once per minute in rrd4j; only the
  per-change storage and the `events.log` lines were removed.

## Ports

| Service | IP | Port | Protocol | Purpose |
|---------|----|------|----------|---------|
| openHAB | 192.168.0.22 | 80 → 8080 | TCP | Web UI (HTTP) |
| openHAB | 192.168.0.22 | 8443 | TCP | Web UI (HTTPS) |
| openHAB | 192.168.0.22 | 5683 | UDP | CoIoT peer |
| openHAB | 192.168.0.22 | 5684 | TCP | CoAP secure |
| MQTT | 192.168.0.23 | 1883 | TCP | MQTT broker |
| MQTT | 192.168.0.23 | 9001 | TCP | MQTT over WebSocket |

## Docker (standalone)

For local/testing without Kubernetes, use `docker/docker-compose.yaml`:

```bash
cd docker
mkdir -p mqtt/config mqtt/data
cp /path/to/mosquitto.conf mqtt/config/mosquitto.conf   # same content as the ConfigMap above
docker compose up -d
```

| Service | Image | Container name | Restart | Ports (host:container) |
|---------|-------|----------------|---------|------------------------|
| `mosquitto` | `eclipse-mosquitto:2.1.2-alpine` | `mqtt` | `always` | `1883:1883`, `9001:9001` |
| `openhab` | `openhab/openhab:5.2.2-alpine` | `openhab` | `always` | `8080:8080`, `8443:8443`, `5683:5683/udp`, `5684:5684` |

| Service | Host path (relative to `docker/`) | Container path |
|---------|-----------------------------------|----------------|
| `mosquitto` | `./mqtt/config/mosquitto.conf` | `/mosquitto/config/mosquitto.conf` |
| `mosquitto` | `./mqtt/data` | `/mosquitto/data` |
| `openhab` | `./openhab/conf/<dir>` (items, things, rules, scripts, sitemaps, services, persistence, transform, html, icons/classic, automation, sounds, misc) | `/openhab/conf/<dir>` |
| `openhab` | `./openhab/userdata` | `/openhab/userdata` |
| `openhab` | `./openhab/addons` | `/openhab/addons` |

openHAB environment in Compose: `OPENHAB_HTTP_PORT=8080`, `OPENHAB_HTTPS_PORT=8443`,
`TZ=Europe/Berlin`, `EXTRA_JAVA_OPTS=-Duser.timezone=Europe/Berlin -Djdk.tls.server.enableSessionTicketExtension=false`. Both services use
the Compose network `default`. The MQTT bridge in `conf/things/mqtt.things` connects to
host `mqtt`: in Kubernetes that is the Service name, in Compose the container name.

## CI

`.github/workflows/check-secrets.yml` runs `scripts/check-no-secrets.sh .` on every pull
request to `main` and every push to `main`. The script fails on plain-text
password/token values in YAML, hardcoded credential literals in `*.sh`, `*.py`,
`*.conf`, `*.ini` and `*.cfg` files, hardcoded NFS server IPs and committed
`last-applied-configuration` annotations. Run it locally with
`bash scripts/check-no-secrets.sh .`.

`scripts/openhab-health-check.py` prints pod, REST, thing and log status. It connects to
the k3s control-plane node with SSH as `mr`, reading the password from `MR0_SSH_PASSWORD`
(fallback: `MR_SSH_PASSWORD`), and requires `paramiko`. REST calls run inside the pod
without credentials, so `/rest/things` answers HTTP 401 and the thing list is not shown.

## Files

```
kubernetes/
├── openhab/
│   ├── app.yaml             # ArgoCD Application: mr-do-openhab
│   ├── deployment.yml       # openHAB Deployment (image, JVM options, probes, resources, mounts)
│   ├── service.yml          # openHAB Service (LoadBalancer 192.168.0.22)
│   ├── pv.yml               # PersistentVolume (NFS)
│   ├── pvc.yml              # PersistentVolumeClaim
│   ├── apply.sh             # Deploy + verify
│   └── delete.sh            # Teardown (with confirmation)
└── mqtt/
    ├── app.yaml             # ArgoCD Application: mqtt
    ├── configmap.yaml       # mosquitto.conf ConfigMap
    ├── deployment.yml       # Mosquitto Deployment (standalone, no openhab deps)
    ├── service.yml          # MQTT Service (named mqtt)
    ├── pv.yml               # PersistentVolume (NFS, dedicated)
    ├── pvc.yml              # PersistentVolumeClaim
    ├── apply.sh             # Deploy + verify
    └── delete.sh            # Teardown (with confirmation)
docker/
└── docker-compose.yaml      # Standalone Docker deployment
openhab-config-staging/
└── conf/                    # Reference copy of the file-based openHAB configuration
scripts/
├── check-no-secrets.sh      # CI secrets guard
└── openhab-health-check.py  # Health check over SSH
```

## Credits

- [openHAB](https://www.openhab.org/)
- [openHAB Docker](https://www.openhab.org/docs/installation/docker.html)

## Development

Work on feature branches only. Never commit directly to `main`.

```bash
git checkout -b feature/your-change
# ... make changes ...
git commit -m "feat: description"
git push -u origin feature/your-change
# Open PR to main
```
