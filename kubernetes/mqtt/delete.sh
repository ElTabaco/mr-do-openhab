#!/bin/bash
set -euo pipefail

echo "WARNING: This will DELETE the MQTT service (mqtt)"
echo "         including the mqtt Deployment and Service in namespace mr-do-openhab"
echo ""
read -r -p "Type 'yes' to confirm deletion: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo "Deleting ArgoCD Application..."
kubectl patch application mqtt -n argocd --type=merge -p '{"operation": null}' || true
kubectl patch application mqtt -n argocd --type=merge -p '{"metadata":{"finalizers":[]}}' || true
kubectl delete application mqtt -n argocd --ignore-not-found || true

echo "Deleting MQTT resources..."
kubectl delete deployment mqtt -n mr-do-openhab --ignore-not-found || true
kubectl delete service mqtt -n mr-do-openhab --ignore-not-found || true

echo "Done."
