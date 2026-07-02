# Proposal: Mount only user-specific files and folders

Status: APPROVED

---

## 1. Current state

A single PersistentVolume (`mr-do-openhab-pv-data`, 4 GiB, NFS at `mr0.local:/srv/nfs4/homes/mr/openhab`) is shared by both containers in the pod via `subPath`:

| Container | Mount path | subPath | What it shadows |
|-----------|-----------|---------|-----------------|
| mqtt | `/mosquitto/data` | `mqtt/data` | none - fine |
| mqtt | `/mosquitto/config/mosquitto.conf` | `mqtt/config/mosquitto.conf` | none - fine |
| openhab | `/openhab/userdata` | `openhab/userdata` | **image runtime files** |
| openhab | `/openhab/conf` | `openhab/conf` | **image defaults** |

### Problem

Mounting the **entire** `/openhab/conf` and `/openhab/userdata` directories has two side effects:

1. **Image defaults are hidden.** On first boot the container initializes from files baked into the image. With a bind-mount over the whole directory, empty/missing dirs are created on the PV but the image's starter content (services templates, logging config, Karaf distribution files) is **shadowed**, not copied. This causes confusing first-run behavior and makes image upgrades silently drop config.
2. **Runtime garbage is persisted.** Everything under `userdata/` (cache, tmp, logs, bundle state, KARAF data) is written to NFS. That is slow, wastes the 4 GiB PV, and is not user-specific - it is regenerable runtime state that should live on ephemeral or local storage.

Only a **small subset** of these trees is actually user-owned configuration and should be persisted.

---

## 2. What is actually user-specific?

### openHAB - keep on PV (user config and state)

| Path | Purpose | Must persist? |
|------|---------|---------------|
| `/openhab/conf/items/` | Item definitions | YES |
| `/openhab/conf/things/` | Thing definitions | YES |
| `/openhab/conf/rules/` | Rules | YES |
| `/openhab/conf/scripts/` | Scripts | YES |
| `/openhab/conf/sitemaps/` | UI sitemaps | YES |
| `/openhab/conf/services/` | `addons.cfg`, `runtime.cfg`, etc | YES |
| `/openhab/conf/persistence/` | Persistence strategies | YES |
| `/openhab/conf/transformations/` | Map/JS/XSLT transforms (singular dir: 'transform') | YES |
| `/openhab/conf/html/` | Static web resources | YES |
| `/openhab/conf/icons/classic/` | Custom icons | YES |
| `/openhab/userdata/jsondb/` | **Runtime config DB** (Items/Things/Links created via UI/MainUI) | YES |
| `/openhab/userdata/secrets/` | Instance UUID + secret (openHAB Cloud identification) | YES |
| `/openhab/userdata/config/` | OSGi Config Admin (Cloud Connector settings, addon configs) | YES |
| `/openhab/addons/` | Manually installed add-ons (keep - unknown if used) | YES |

### openHAB - do NOT persist (runtime / regenerable)

| Path | Why skip |
|------|----------|
| `/openhab/userdata/cache/` | Downloaded artifact cache - regenerated |
| `/openhab/userdata/tmp/` | Temp files - regenerated |
| `/openhab/userdata/logs/` | Logs - removed from PV (decision: remove) |
| `/openhab/userdata/etc/` | Karaf/runtime config - regenerated from image (decision: not customized) |

### Mosquitto - keep on PV (already correct)

| Path | Must persist? |
|------|---------------|
| `/mosquitto/data` (subPath `mqtt/data`) | YES - persistence DB |
| `/mosquitto/config/mosquitto.conf` (subPath `mqtt/config/mosquitto.conf`) | YES - user config |

No change needed for MQTT.

---

## 3. Approved change

Replace the two coarse `conf`/`userdata` mounts with **granular subPath mounts**, one per user-specific directory. Same single PV, same NFS share - just narrower subPaths.

### Decisions applied

| # | Question | Decision |
|---|----------|----------|
| 1 | Additional mounting (persistence data)? | NO - no additional mounts beyond the user-specific dirs |
| 2 | Customized `userdata/etc/`? | NO - not persisted, image defaults used |
| 3 | Manual add-ons installation? | UNKNOWN - keep `/openhab/addons` mounted to be safe |
| 4 | PV size? | KEEP at 4 GiB |
| 5 | Logs on NFS? | REMOVE - no log mount |

### Updated deployment manifest

The updated `kubernetes/mr-do-openhab-deployment.yml` replaces these two mounts:

```yaml
# REMOVED (coarse, shadowed image defaults):
- mountPath: /openhab/userdata
  subPath: openhab/userdata
- mountPath: /openhab/conf
  subPath: openhab/conf
```

with these granular mounts:

```yaml
# ADDED (user-specific only):
# conf
- mountPath: /openhab/conf/items
  subPath: openhab/conf/items
- mountPath: /openhab/conf/things
  subPath: openhab/conf/things
- mountPath: /openhab/conf/rules
  subPath: openhab/conf/rules
- mountPath: /openhab/conf/scripts
  subPath: openhab/conf/scripts
- mountPath: /openhab/conf/sitemaps
  subPath: openhab/conf/sitemaps
- mountPath: /openhab/conf/services
  subPath: openhab/conf/services
- mountPath: /openhab/conf/persistence
  subPath: openhab/conf/persistence
- mountPath: /openhab/conf/transform
  subPath: openhab/conf/transform
- mountPath: /openhab/conf/html
  subPath: openhab/conf/html
- mountPath: /openhab/conf/icons/classic
  subPath: openhab/conf/icons/classic
- mountPath: /openhab/conf/automation/jsr223
  subPath: openhab/conf/automation/jsr223
- mountPath: /openhab/conf/sounds
  subPath: openhab/conf/sounds
- mountPath: /openhab/conf/misc
  subPath: openhab/conf/misc
# userdata
- mountPath: /openhab/userdata/jsondb
  subPath: openhab/userdata/jsondb
- mountPath: /openhab/userdata/secrets
  subPath: openhab/userdata/secrets
- mountPath: /openhab/userdata/config
  subPath: openhab/userdata/config
- mountPath: /openhab/userdata/kar
  subPath: openhab/userdata/kar
- mountPath: /openhab/userdata/persistence
  subPath: openhab/userdata/persistence
- mountPath: /openhab/userdata/openhabcloud
  subPath: openhab/userdata/openhabcloud
- mountPath: /openhab/userdata/uuid
  subPath: openhab/userdata/uuid
# addons
- mountPath: /openhab/addons
  subPath: openhab/addons
```

### PV / PVC

No change. Same PV (4 GiB, NFS), same PVC.

---

## 4. Trade-offs

| Aspect | Coarse (old) | Granular (new) |
|--------|------------------|---------------------|
| Image defaults visible | NO - shadowed | YES (clean upgrades) |
| Runtime state on NFS | YES (slow, wastes space) | only user data persisted |
| First-run behaviour | unexpected | predictable |
| Manifest verbosity | short | longer (more volumeMounts) |
| Adding a new conf subdir | implicit | must add explicit mount (maintenance cost) |
| Backup granularity | whole tree | only what matters |

**Main cost:** any new openHAB config directory added in a future release must be added as an explicit `volumeMount`.

---

## 5. Migration plan

1. **Backup** current PV contents to a safe location off NFS.
2. **Reorganize** the NFS tree to the new subPath layout - the existing `openhab/conf/` and `openhab/userdata/` dirs already match, so mostly we just **stop mounting** the unwanted subdirs; no data move required for the kept paths.
3. **Prune** from the PV: `userdata/cache`, `userdata/tmp`, `userdata/log`, `userdata/etc`.
4. **Apply** updated `mr-do-openhab-deployment.yml`.
5. **Rolling restart**, verify openHAB boots and MainUI shows items/things/rules intact.
6. **Smoke test**: trigger a rule, confirm persistence writes, confirm MQTT round-trip.

---

## 6. Files changed

| File | Change |
|------|--------|
| `kubernetes/mr-do-openhab-deployment.yml` | Coarse mounts replaced with 21 granular subPath mounts |
| `PROPOSAL-user-specific-mounts.md` | This document (status APPROVED) |

PV, PVC, Service, App manifests unchanged.
