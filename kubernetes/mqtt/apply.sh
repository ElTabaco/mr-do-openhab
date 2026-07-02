#!/bin/bash
set -euo pipefail

# Self-locate: ensure we run from repo root regardless of cwd
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Apply MQTT ArgoCD Application
kubectl apply -f "$REPO_ROOT/kubernetes/mqtt/app.yaml"


# ── Verification (non-fatal) ──
echo ""
echo "=== MQTT Pods ==="
kubectl get pods -n mr-do-openhab -l app=mqtt -o wide || true

echo ""
echo "=== MQTT Service ==="
kubectl get svc mqtt -n mr-do-openhab || true

echo ""
echo "=== PVC (shared with openHAB) ==="
kubectl describe pvc mqtt-pvc-data -n mr-do-openhab || true

echo ""
echo "=== MQTT PV ==="
kubectl describe pv mr-do-openhab-pv-data || true
