kubectl delete -f mr-do-openhab-deployment.yml
kubectl delete -f mr-do-openhab-services.yml
kubectl delete -f mr-do-openhab-pvc.yml
kubectl delete -f mr-do-openhab-pv.yml

kubectl delete all,deployment,sc,pv,pvc --all -n mr-do-openhab
kubectl delete namespace mr-do-openhab


# argocd sync mr-do-openhab --prune -n argocd

kubectl delete pod argocd-application-controller-0 -n argocd --grace-period=0 --force --wait=false
kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=300s