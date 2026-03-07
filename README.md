# mr-do-openhab
openhab on kubernetes cluster

## Mian credits
* [openHAB](https://www.openhab.org/)
* [openHAB docker](https://www.openhab.org/docs/installation/docker.html)




Ich habe dir **zwei Dateien vorbereitet**:

* 📜 Bash-Script → erstellt / löscht sauber die ArgoCD Application
* 📘 Markdown → Dokumentation der Schritte

Beide nutzen jetzt **`mr-do-openhab` statt `mr-do-openhab-new`**.

---

# 1️⃣ Bash Script

Datei:

```bash
create-openhab-argocd.sh
```

```bash
#!/bin/bash

set -e

APP="mr-do-openhab"
NAMESPACE="mr-do-openhab"
REPO="https://github.com/ElTabaco/mr-do-openhab.git"

echo "Deleting old ArgoCD application (if exists)..."

kubectl delete application $APP -n argocd --ignore-not-found

echo "Removing stuck finalizers if necessary..."

kubectl patch application $APP -n argocd --type=merge -p '{"metadata":{"finalizers":[]}}' || true

echo "Deleting namespace (clean start)..."

kubectl delete namespace $NAMESPACE --ignore-not-found

echo "Waiting for namespace deletion..."

while kubectl get namespace $NAMESPACE >/dev/null 2>&1; do
  sleep 2
done

echo "Creating namespace..."

kubectl create namespace $NAMESPACE

echo "Creating ArgoCD Application..."

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP
  namespace: argocd
spec:
  project: default

  source:
    repoURL: $REPO
    targetRevision: main
    path: .

  destination:
    server: https://kubernetes.default.svc
    namespace: $NAMESPACE

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo ""
echo "Application deployed."
echo ""

kubectl get applications -n argocd
```

Script ausführbar machen:

```bash
chmod +x create-openhab-argocd.sh
```

Start:

```bash
./create-openhab-argocd.sh
```

---

# 2️⃣ Markdown Dokumentation

Datei:

```text
openhab-argocd.md
```

````markdown
# OpenHAB ArgoCD Deployment

Dieses Dokument beschreibt, wie die OpenHAB Installation im Kubernetes Cluster über ArgoCD deployt wird.

Repository:

https://github.com/ElTabaco/mr-do-openhab

Namespace:

mr-do-openhab

Application Name:

mr-do-openhab

---

# Clean Deployment

Application löschen

kubectl delete application mr-do-openhab -n argocd

Falls sie festhängt:

kubectl patch application mr-do-openhab -n argocd --type=merge -p '{"metadata":{"finalizers":[]}}'

Namespace löschen

kubectl delete namespace mr-do-openhab

Namespace neu erstellen

kubectl create namespace mr-do-openhab

---

# Application Deployment

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mr-do-openhab
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/ElTabaco/mr-do-openhab.git
    targetRevision: main
    path: .

  destination:
    server: https://kubernetes.default.svc
    namespace: mr-do-openhab

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
````

Deploy:

```
kubectl apply -f openhab-argocd.yaml
```

---

# Status prüfen

Applications:

```
kubectl get applications -n argocd
```

Pods:

```
kubectl get pods -n mr-do-openhab
```

Services:

```
kubectl get svc -n mr-do-openhab
```

PVC:

```
kubectl get pvc -n mr-do-openhab
```

---

# Manual Sync

```
kubectl annotate application mr-do-openhab -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

```

---

# Ergebnis

Du hast jetzt:

```

create-openhab-argocd.sh
openhab-argocd.md

```

für dein **mr-do-openhab GitOps Deployment**.

---

Wenn du möchtest, kann ich dir noch eine **perfekte GitOps Struktur für dein Repo bauen**, damit du später mehrere Apps sauber mit ArgoCD deployen kannst (OpenHAB, Player, Monitoring usw.).
```
