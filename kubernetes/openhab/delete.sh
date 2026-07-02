#!/bin/bash
set -euo pipefail

echo "WARNING: This will DELETE openHAB resources in namespace mr-do-openhab"
echo "         (Deployment, Service, PV, PVC, ArgoCD Application)"
echo ""
echo "         NOTE: The MQTT app in the same namespace will NOT be affected."
echo "         NOTE: PV reclaim policy is 'Retain' — your data on NFS is safe."
echo ""
read -r -p "Type 'yes' to confirm deletion: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

echo "Deleting ArgoCD Application..."
kubectl patch application mr-do-openhab -n argocd --type=merge -p '{"operation": null}' || true
kubectl patch application mr-do-openhab -n argocd --type=merge -p '{"metadata":{"finalizers":[]}}' || true
kubectl delete application mr-do-openhab -n argocd --ignore-not-found || true

echo "Deleting openHAB Deployment and Service..."
kubectl delete deployment mr-do-openhab -n mr-do-openhab --ignore-not-found || true
kubectl delete service mr-do-openhab-service -n mr-do-openhab --ignore-not-found || true

echo "Deleting PVC (PV has Retain policy, will survive)..."
kubectl delete pvc mr-do-openhab-pvc-data -n mr-do-openhab --ignore-not-found || true

echo ""
echo "To delete the PV too, run manually:"
echo "  kubectl delete pv mr-do-openhab-pv-data"

echo "Done."
