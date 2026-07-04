# openHAB First-Boot Checklist

After NFS fix and pod startup, openHAB will boot as a **fresh install** (all previous data was on mr1 — deleted).

## Step 1: Fix NFS (on mr0)

```bash
sudo sed -i '/sdb1/d' /etc/fstab
sudo systemctl daemon-reload
sudo systemctl start nfs-server
sudo exportfs -ra
sudo ss -tlnp | grep 2049   # verify
```

## Step 2: Restart pods

```bash
kubectl rollout restart deployment/mqtt deployment/mr-do-openhab -n mr-do-openhab
kubectl get pods -n mr-do-openhab -w
```

## Step 3: openHAB Setup Wizard

Open http://192.168.0.22 in browser:
- Create admin user
- Set location, timezone (Europe/Berlin)

## Step 4: Install Add-ons

MainUI → Settings → Add-ons → install:
- MQTT Binding
- MobileAlerts Binding
- rrd4j Persistence
- openHAB Cloud Connector
- MapDB Persistence (optional, for restoreOnStartup)
- Exec Binding (if using scripts)
- Shelly Binding (if using Shelly devices)
- miio Binding (if using Xiaomi devices)

## Step 5: Configure MQTT Broker

MainUI → Things → Add → MQTT Binding → Broker:
- Name: MQTT Broker
- Hostname: mqtt
- Port: 1883

## Step 6: Recreate Items, Things, Rules

### Previous Items (from NFS listing):
- kuhStahl items (conf/items/kuhStahl.items)

### Previous Things:
- mobileAlerts (conf/things/mobileAlerts.things)

### Previous Rules (8 total):
- eggSumPower.rules
- guellePressure.rules
- kuhStahlSensoren.rules
- redGarageDoor_Input.rules
- stoeckliSmocke.rules
- viehhueterNordTimer.rules
- viehhueterSuedTimer.rules

### Previous Scripts:
- mobileAlerts_REST_API.sh

## Step 7: Recreate Configuration Files

### Transform maps (conf/transform/):
```map
# de.map
NULL=-
ON=An
OFF=Aus
```

### exec.whitelist (conf/misc/):
Add allowed commands for exec binding.

### Persistence (conf/persistence/):
```persist
Strategies {
    everyMinute : "0 * * * * ?"
    everyHour : "0 0 * * * ?"
    default : everyChange
}
Items {
    * : strategy = everyChange, everyMinute, restoreOnStartup
}
```

## Step 8: openHAB Cloud (optional)

1. Register at https://myopenhab.org
2. MainUI → Settings → openHAB Cloud
3. Enter UUID + secret from myopenhab.org

## Step 9: Upload Sound Files

Copy to NFS at /srv/nfs4/homes/mr/openhab/openhab/conf/sounds/:
- alarm.mp3
- doorbell.mp3
- mario.mp3

## Step 10: Verify

- Check MainUI shows all Things online
- Test a rule manually
- Verify MQTT: `mosquitto_sub -h 192.168.0.23 -t "#" -v`
- Verify persistence: check rrd4j charts in MainUI
