#!/bin/bash
# Auto-runs after you mount the NFS share.
# Shows the directory tree we need to align Kubernetes mounts against.
echo "=== /srv/nfs4/homes/mr/openhab on mr0.local ==="
echo ""
echo "--- All directories (maxdepth 3) ---"
find /workspace/mr-do-openhab/nfs-scan -maxdepth 3 -type d 2>/dev/null | sort
echo ""
echo "--- File counts per top-level dir ---"
find /workspace/mr-do-openhab/nfs-scan -maxdepth 2 -mindepth 1 -type d -exec sh -c 'echo "$(find "$0" -maxdepth 1 -mindepth 1 | wc -l) items in $0"' {} \;
echo ""
echo "--- Symlinks (relevant for aliasing) ---"
find /workspace/mr-do-openhab/nfs-scan -maxdepth 3 -type l 2>/dev/null
echo ""
echo "--- Total size ---"
du -sh /workspace/mr-do-openhab/nfs-scan
