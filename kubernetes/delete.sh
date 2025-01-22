kubectl delete -f mr-do-openhab-deployment.yml
kubectl delete -f mr-do-openhab-services.yml
kubectl delete -f mr-do-openhab-pvc.yml
kubectl delete -f mr-do-openhab-pv.yml

kubectl delete all,deployment,sc,pv,pvc --all -n mr-do-openhab
kubectl delete namespace mr-do-openhab
