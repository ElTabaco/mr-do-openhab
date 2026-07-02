#!/bin/bash
set -euo pipefail

# Apply ArgoCD Application
kubectl apply -f kubernetes/openhab/app.yaml

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
