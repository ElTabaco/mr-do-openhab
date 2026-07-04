#!/bin/bash
set -euo pipefail

echo "WARNING: This will DELETE the 'mqtt' resources in namespace mr-do-openhab"
echo "         (Deployment, Service, ArgoCD Application)"
echo ""
echo "         NOTE: The openHAB app in the same namespace will NOT be affected."
echo "         NOTE: This app's own PVC (mqtt-pvc-data) WILL be deleted."
echo "               PV has Retain policy - your data on NFS survives."
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

echo "Deleting PVC (PV has Retain policy, data on NFS is safe)..."
kubectl delete pvc mqtt-pvc-data -n mr-do-openhab --ignore-not-found || true

echo ""
echo "To delete the PV too, run manually:"
echo "  kubectl delete pv mqtt-pv-data"

echo "Done."
