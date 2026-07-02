#!/bin/bash
set -euo pipefail

echo "WARNING: This will DELETE all resources in namespace mr-do-openhab"
echo "         including PV mr-do-openhab-pv-data (reclaim policy: Retain)"
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

echo "Deleting resources..."
kubectl delete all --all -n mr-do-openhab --wait=false || true
kubectl delete pvc --all -n mr-do-openhab --wait=false || true
kubectl delete pod --all -n mr-do-openhab --grace-period=0 --force --wait=false || true

echo "Deleting namespace..."
kubectl delete ns mr-do-openhab --ignore-not-found --wait=false || true
kubectl patch namespace mr-do-openhab -p '{"spec":{"finalizers":[]}}' --type=merge || true

echo "Deleting PV..."
kubectl delete pv mr-do-openhab-pv-data --ignore-not-found || true

echo "Done."
