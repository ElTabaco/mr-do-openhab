# Reference copy. The live file on NFS contains the real MobileAlerts device IDs and phone ID.
curl -s -X POST -d deviceids=<DEVICE_IDS> -d phoneid=<PHONE_ID> https://www.data199.com/api/pv1/device/lastmeasurement
