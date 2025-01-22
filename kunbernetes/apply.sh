kubectl create namespace mr-do-openhab

kubectl apply -f mr-do-openhab-pv.yml
kubectl apply -f mr-do-openhab-pvc.yml
kubectl apply -f mr-do-openhab-services.yml
kubectl apply -f mr-do-openhab-deployment.yml

kubectl describe pod mr-do-openhab -n mr-do-openhab
kubectl get pods --all-namespaces -o wide
kubectl describe pv mr-do-openhab-pv-data -n mr-do-openhab
kubectl describe pvc mr-do-openhab-pvc-data -n mr-do-openhab
kubectl get svc -n mr-do-openhab
kubectl describe services mr-do-openhab-service -n mr-do-openhab

kubectl get all -n mr-do-openhab

# sudo kubectl log <containername>
# sudo kubectl label nodes mr-00 cputype=arm64