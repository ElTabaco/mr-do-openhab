# mr-do-openhab

[openHAB](https://www.openhab.org/) home automation on Kubernetes, deployed via ArgoCD GitOps.

Runs two services:
- **openHAB** — automation runtime (web UI, rules, things, items)
- **Mosquitto** — MQTT broker

## Architecture

```
ArgoCD ── watches repo ──> kubernetes/*.yml
                              │
                ┌─────────────┴──────────────┐
                │                            │
         openHAB Deployment            MQTT Deployment
         (web UI, rules)               (broker)
                │                            │
         openHAB Service              MQTT Service
         (LB: 192.168.0.22)           (LB)
                │                            │
                └──────── shared PV ─────────┘
                  (NFS 4GiB, mr0.local)
```

## Deployment

Everything is deployed via ArgoCD. The Application manifest lives in
`kubernetes/mr-do-openhab-app.yaml`.

### Deploy / Apply

```bash
./kubernetes/apply.sh
```

### Delete / Teardown

```bash
./kubernetes/delete.sh
# Type 'yes' to confirm
```

### Manual sync (force ArgoCD refresh)

```bash
kubectl annotate application mr-do-openhab -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
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

The compose file mirrors the same granular mount strategy as Kubernetes.

## Files

```
kubernetes/
├── mr-do-openhab-app.yaml          # ArgoCD Application (GitOps)
├── mr-do-openhab-deployment.yml    # 2 Deployments: openhab + mqtt
├── mr-do-openhab-services.yml      # 2 LoadBalancer Services
├── mr-do-openhab-pv.yml            # PersistentVolume (NFS)
├── mr-do-openhab-pvc.yml           # PersistentVolumeClaim
├── apply.sh                        # Deploy + verify
└── delete.sh                       # Teardown (with confirmation)
docker/
└── docker-compose.yaml             # Standalone Docker deployment
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
