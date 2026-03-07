kubectl apply -f mr-do-openhab-app.yaml

kubectl describe pod mr-do-openhab -n mr-do-openhab
kubectl get pods --all-namespaces -o wide
kubectl describe pv mr-do-openhab-pv-data -n mr-do-openhab
kubectl describe pvc mr-do-openhab-pvc-data -n mr-do-openhab
kubectl get svc -n mr-do-openhab
kubectl describe services mr-do-openhab-service -n mr-do-openhab

kubectl get all -n mr-do-openhab

# kubectl log <containername>