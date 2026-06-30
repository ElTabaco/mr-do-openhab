# Audit: Optimization and Improvement Opportunities

Scanned: all files in repo. Findings prioritized BUG > SECURITY > RELIABILITY > MAINTAINABILITY > DRIFT.

---

## BUG (broken right now)

| # | File | Issue | Fix |
|---|------|-------|-----|
| B1 | `docker/docker-compose.yaml:21` | **Double `:latest` in image tag**: `openhab/openhab:latest-alpine:latest` — invalid tag, Docker pull will fail | Change to `openhab/openhab:4.3.5-alpine` |
| B2 | `kubernetes/delete.sh:14` | **Wrong PV name**: `kubectl delete pv mr-pv-data` — actual PV is named `mr-do-openhab-pv-data`. Command always fails silently | Fix to `mr-do-openhab-pv-data` |
| B3 | `kubernetes/apply.sh:3` | **Wrong pod name**: `kubectl describe pod mr-do-openhab` — pod name is `mr-do-openhab-<replicaset-hash>`, not bare name | Use `kubectl describe pod -l app=mr-do-openhab -n mr-do-openhab` |
| B4 | `kubernetes/apply.sh:5` | **Namespace flag on cluster-scoped resource**: `kubectl describe pv ... -n mr-do-openhab` — PVs are cluster-scoped, `-n` is ignored | Remove `-n` flag |
| B5 | `README.md:167-169` | **Unclosed code block**: empty triple-backtick block leaves rendering broken | Remove or close properly |

---

## SECURITY

| # | File | Issue | Fix |
|---|------|-------|-----|
| S1 | deployment.yml | **No securityContext** — both containers run as root. openHAB image defaults to root | Add `runAsNonRoot: true`, `runAsUser: 9001` (openhab user), `fsGroup: 9001` |
| S2 | deployment.yml | **No readOnlyRootFilesystem** — container root FS is writable | Add `readOnlyRootFilesystem: true` (mount writable dirs explicitly) |
| S3 | services.yml:10 | **Hardcoded loadBalancerIP `192.168.0.22`** in Git — leaks internal network topology | Move to overlay/sealed-secret or use MetalLB IP pool annotation |

---

## RELIABILITY

| # | File | Issue | Fix |
|---|------|-------|-----|
| R1 | deployment.yml | **No liveness/readiness probes** — K8s can't detect if openHAB is actually serving or MQTT is alive | Add `readinessProbe` (HTTP GET `/`) + `livenessProbe` for openhab; TCP probe for mqtt:1883 |
| R2 | deployment.yml | **No resource requests/limits** — noisy neighbor risk, no OOM protection | Add CPU/memory requests + limits for both containers |
| R3 | deployment.yml | **mqtt + openhab in same pod** — MQTT restart takes openHAB down with it | Split into 2 Deployments (separate failure domains). They communicate via ClusterIP Service |
| R4 | deployment.yml | **No pod anti-affinity / node selector** — pod can land on any node, no control | Add `nodeSelector` or topology constraints |
| R5 | deployment.yml | **No `updateStrategy` / rollback** — bad rollout has no automatic rollback | Add `strategy: RollingUpdate` with maxSurge/maxUnavailable |
| R6 | deployment.yml:20 | **Mosquitto uses `:latest` tag** — unpredictable, breaks reproducibility on image rebuilds | Pin to a version, e.g. `eclipse-mosquitto:2.0.20` |
| R7 | app.yaml | **No ArgoCD `ignoreDifferences`** — LoadBalancer assigns external IP/status that ArgoCD tries to self-heal away | Add `ignoreDifferences` for Service status fields |

---

## MAINTAINABILITY

| # | File | Issue | Fix |
|---|------|-------|-----|
| M1 | `apply.sh`, `delete.sh` | **No shebang** (`#!/bin/bash`) and **no `set -euo pipefail`** | Add both |
| M2 | `apply.sh` | **Mixes apply + describe in one script** — apply should fail fast, describe is verification | Split into `apply.sh` + `verify.sh` or add `set -e` before apply, `|| true` on describe |
| M3 | `delete.sh` | **Force-deletes namespace finalizers without warning** — destructive, irreversible | Add `read -p "Confirm deletion of namespace mr-do-openhab? (yes/no)"` guard |
| M4 | README.md | **Chat-log paste, not documentation** — contains German ChatGPT output, references non-existent files (`create-openhab-argocd.sh`, `openhab-argocd.md`), mixes languages | Rewrite as clean repo README |
| M5 | whole repo | **No `.gitignore`** | Add one (ignore `*.swp`, `.env`, `*.bak`, etc.) |
| M6 | pv.yml | **Hardcoded NFS server `mr0.local` + path** — not portable, can't reuse for other environments | Document as environment-specific or parameterize via Kustomize overlay |

---

## DRIFT (docker-compose vs kubernetes)

| # | File | Issue | Fix |
|---|------|-------|-----|
| D1 | docker-compose.yaml | **Still uses coarse volume mounts** (`./openhab/conf`, `./openhab/userdata`) — K8s was updated, Docker wasn't | Apply same granular mount strategy |
| D2 | docker-compose.yaml:28-29 | **Port mismatch**: Compose uses 8081/8444, K8s uses 8080/8443 | Align to one set |
| D3 | docker-compose.yaml:1 | **`version: '3'` is obsolete** — Compose Spec no longer requires it | Remove the `version` key |
| D4 | docker-compose.yaml:31 | **`network_mode: host`** for openhab but bridge for mosquitto — inconsistent | Use bridge for both, or document why host mode is needed |

---

## Summary

| Severity | Count |
|----------|-------|
| BUG | 5 |
| SECURITY | 3 |
| RELIABILITY | 7 |
| MAINTAINABILITY | 6 |
| DRIFT | 4 |
| **Total** | **25** |

### Recommended fix order

1. **BUG fixes** (B1-B5) — these are broken right now, quick wins
2. **D1-D2 drift** — bring docker-compose in line with K8s changes
3. **R1-R2** — probes + resource limits (biggest reliability impact)
4. **S1-S2** — securityContext (security posture)
5. **M1-M5** — script hardening + README rewrite
6. **R3-R7, S3, M6** — architectural improvements (larger scope, decide per-item)
