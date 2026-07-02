#!/bin/bash
set -euo pipefail

echo "WARNING: This will DELETE the 'mqtt' resources in namespace mr-do-openhab"
echo "         (Deployment, Service, ArgoCD Application)"
echo ""
echo "         NOTE: The openHAB app in the same namespace will NOT be affected."
echo "         NOTE: The shared PVC mr-do-openhab-pvc-data is also NOT touched."
echo "               It is used by openHAB and will outlive this deletion."
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

echo "Deleting MQTT Deployment and Service..."
kubectl delete deployment mqtt -n mr-do-openhab --ignore-not-found || true
kubectl delete service mqtt -n mr-do-openhab --ignore-not-found || true

echo "Done."
