kubectl delete -f mr-do-openhab-deployment.yml
kubectl delete -f mr-do-openhab-services.yml
kubectl delete -f mr-do-openhab-pvc.yml
kubectl delete -f mr-do-openhab-pv.yml
kubectl delete namespace mr-do-openhab
