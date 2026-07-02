#!/bin/bash
set -euo pipefail

# Apply MQTT ArgoCD Application
kubectl apply -f kubernetes/mqtt/app.yaml

# ── Verification (non-fatal) ──
echo ""
echo "=== MQTT Pods ==="
kubectl get pods -n mr-do-openhab -l app=mr-do-openhab-mqtt -o wide || true

echo ""
echo "=== MQTT Service ==="
kubectl get svc mr-do-openhab-mqtt -n mr-do-openhab || true
