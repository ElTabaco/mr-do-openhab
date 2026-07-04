#!/bin/bash
set -euo pipefail

# Self-locate: ensure we run from repo root regardless of cwd
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Apply ArgoCD Application
kubectl apply -f "$REPO_ROOT/kubernetes/openhab/app.yaml"


# ── Verification (non-fatal) ──
echo ""
echo "=== Pods ==="
kubectl get pods -n mr-do-openhab -o wide || true

echo ""
echo "=== Services ==="
kubectl get svc -n mr-do-openhab || true

echo ""
echo "=== PVC ==="
kubectl describe pvc mr-do-openhab-pvc-data -n mr-do-openhab || true

echo ""
echo "=== PV ==="
kubectl describe pv mr-do-openhab-pv-data || true

echo ""
echo "=== All resources ==="
kubectl get all -n mr-do-openhab || true
