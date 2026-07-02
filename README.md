# mr-do-openhab

[openHAB](https://www.openhab.org/) home automation on Kubernetes, deployed via ArgoCD GitOps.

Two **independent** applications, each with its own ArgoCD Application and Service:

- **openHAB** — automation runtime (web UI, rules, things, items)
- **Mosquitto** — MQTT broker (standalone, reusable for other apps)

## Architecture

```
ArgoCD
  ├── Application: mr-do-openhab      → kubernetes/openhab/
  │     ├── Deployment (openhab: 9001)
  │     ├── Service (LoadBalancer 192.168.0.22)
  │     ├── PV + PVC (4 GiB NFS)
  │     └── granular subPath mounts for user-specific config
  │
  └── Application: mqtt  → kubernetes/mqtt/
        ├── Deployment (eclipse-mosquitto: 2.0.20)
        └── Service (LoadBalancer, dynamic IP)
```

The two apps share the same NFS volume (PV/PVC lives under `openhab/` because
openHAB owns the user-config files). MQTT uses `subPath: mqtt/data` and
`subPath: mqtt/config/mosquitto.conf` from the same PV.

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
kubectl annotate application mr-do-openhab     -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application mqtt -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

## Persistent Storage

| Resource | Detail |
|----------|--------|
| PV | `mr-do-openhab-pv-data` (4 GiB, NFS, Retain) |
| NFS Server | `mr0.local:/srv/nfs4/homes/mr/openhab` |
| PVC | `mr-do-openhab-pvc-data` (ReadWriteMany) |

**Mount strategy:** Only user-specific config and state directories are persisted
(granular subPath mounts). Runtime data (cache, tmp, logs) stays ephemeral.
See [PROPOSAL-user-specific-mounts.md](PROPOSAL-user-specific-mounts.md) for details.

## Ports

| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| openHAB | 80 → 8080 | TCP | Web UI (HTTP) |
| openHAB | 8443 | TCP | Web UI (HTTPS) |
| openHAB | 5683 | UDP | CoIoT peer |
| openHAB | 5684 | TCP | CoAP secure |
| MQTT | 1883 | TCP | MQTT broker |
| MQTT | 9001 | TCP | MQTT over WebSocket |

## Docker (standalone)

For local/testing without Kubernetes, use `docker/docker-compose.yaml`:

```bash
cd docker
docker compose up -d
```

## Files

```
kubernetes/
├── openhab/
│   ├── app.yaml             # ArgoCD Application: mr-do-openhab
│   ├── deployment.yml       # openHAB Deployment (securityContext, probes, resources)
│   ├── service.yml          # openHAB Service (LoadBalancer 192.168.0.22)
│   ├── pv.yml               # PersistentVolume (NFS)
│   ├── pvc.yml              # PersistentVolumeClaim
│   ├── apply.sh             # Deploy + verify
│   └── delete.sh            # Teardown (with confirmation)
└── mqtt/
    ├── app.yaml             # ArgoCD Application: mqtt
    ├── deployment.yml       # Mosquitto Deployment (standalone, no openhab deps)
    ├── service.yml          # MQTT Service (named mqtt)
    ├── apply.sh             # Deploy + verify
    └── delete.sh            # Teardown (with confirmation)
docker/
└── docker-compose.yaml      # Standalone Docker deployment
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
