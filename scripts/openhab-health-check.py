#!/usr/bin/env python3
"""openHAB Kubernetes Health Check - LLM-independent"""
import sys
try:
    import paramiko
except ImportError:
    sys.path.insert(0, "/workspace/local-llm-optimization/venv/lib/python3.13/site-packages")
    import paramiko
import os
import json

K8S_MASTER = "192.168.0.200"
SSH_USER = "mr"
SSH_PASS = os.environ.get("MR_SSH_PASSWORD", "")
NAMESPACE = "mr-do-openhab"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(K8S_MASTER, username=SSH_USER, password=SSH_PASS, timeout=10)

def run(cmd, timeout=30):
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    return stdout.read().decode(), stderr.read().decode()

def rest(path):
    cmd = f"kubectl exec -n {NAMESPACE} deploy/mr-do-openhab -- sh -c 'wget -qO- http://localhost:8080/rest/{path} 2>&1' 2>&1"
    out, _ = run(cmd)
    raw = out.split("Defaulted")[0].strip() if "Defaulted" in out else out.strip()
    try:
        return json.loads(raw)
    except:
        return None

print("="*60)
print("openHAB Health Check")
print("="*60)

# Pods
out, _ = run(f"kubectl get pods -n {NAMESPACE} 2>&1")
print(f"\nPods:\n{out}")

# REST API
info = rest("")
if info:
    ver = info.get("runtimeInfo", {}).get("version", "?")
    tz = info.get("timezone", "?")
    print(f"REST API: openHAB {ver}, TZ={tz}")

# Items
items = rest("items")
if items is not None:
    print(f"Items: {len(items)}")
else:
    print("Items: (REST not ready or auth required)")

# Things
things = rest("things")
if things is not None:
    print(f"Things: {len(things)}")
    for t in things:
        print(f"  {t.get('label','?')}: {t.get('statusInfo',{}).get('status','?')}")
else:
    print("Things: (REST not ready or auth required)")

# Sitemaps
sitemaps = rest("sitemaps")
if sitemaps is not None:
    print(f"Sitemaps: {len(sitemaps)}")

# Log errors
out, _ = run(f"kubectl exec -n {NAMESPACE} deploy/mr-do-openhab -- sh -c 'grep -c ERROR /openhab/userdata/logs/openhab.log 2>&1' 2>&1")
err_count = out.strip().split("\n")[-1] if out.strip() else "?"
print(f"\nLog errors: {err_count}")

# NFS + MQTT
out, _ = run("systemctl is-active nfs-server 2>&1")
print(f"NFS: {out.strip()}")
out, _ = run(f"kubectl get pods -n {NAMESPACE} -l app=mqtt -o jsonpath='{{.items[0].status.phase}}' 2>&1")
print(f"MQTT pod: {out.strip()}")

# HTTP
out, _ = run("curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 http://192.168.0.22 2>&1")
print(f"openHAB HTTP: {out.strip()}")

client.close()
print("\n" + "="*60)
