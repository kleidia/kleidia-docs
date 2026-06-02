# OpenBao Raft Migration Reference (file → integrated raft)

**Audience**: Operations Administrators
**Prerequisites**: Cluster access (`kubectl`/`k0s`), off-cluster custody of the OpenBao unseal/init keys
**Outcome**: Understand exactly what the migration does — and how to perform it manually for auditing or one-off use

Deployments created before the raft switch run OpenBao with `storage "file"`. File
storage has **no snapshot API**, so the scheduled backup silently failed and the
data lived only on node-local storage. Moving to `storage "raft"` enables
consistent snapshots and is the supported DR backend.

> **This is NOT a hot config flip.** OpenBao cannot read file-backed data under a
> raft config — if you just `helm upgrade` to the raft chart, the pod will fail to
> unseal/start. You must convert the on-disk data with `bao operator migrate`
> **while the server is stopped**, then switch the storage stanza. New deployments
> skip all of this.

## Automated script (recommended)

The automated migration script performs the whole conversion safely: pre-flight
checks + idempotency (no-op if already raft), backs up the data PVC + ConfigMap +
unseal secret, runs `bao operator migrate` in a maintenance pod, switches the
ConfigMap storage stanza, restarts OpenBao, and verifies it comes up on raft +
unsealed. It **auto-reverts to file storage** on any failure, and has a
`--rollback` mode. Old file data is kept at `PVC:/openbao/data/_filebak`.

This is the recommended path — see **[Upgrading an Existing Deployment](../03-deployment/upgrade-file-to-raft.md)**
for how to fetch and run it. Quick reference:

```bash
curl -fsSLO https://raw.githubusercontent.com/kleidia/kleidia-docs/main/scripts/openbao-file-to-raft-migrate.sh
chmod +x openbao-file-to-raft-migrate.sh

./openbao-file-to-raft-migrate.sh            # prompts before the destructive step
./openbao-file-to-raft-migrate.sh -y         # non-interactive
./openbao-file-to-raft-migrate.sh --rollback # revert raft -> file from _filebak
# k0s:
KUBECTL="sudo k0s kubectl" ./openbao-file-to-raft-migrate.sh -y
```

**Validated** on a live k0s deployment: file→raft, auto-unseal, dependent services
intact, raft snapshot working post-migration.

**Prerequisites / gotchas the script handles or you must check:**
- **Brief OpenBao downtime** — the server is stopped during the offline migrate.
- **Node CPU headroom** — stopping OpenBao frees its CPU slot; on a saturated node
  another Pending pod can grab it and block OpenBao from rescheduling. The script
  suspends the `kleidia-backup` CronJob during migration to avoid that race, but
  ensure the node can still schedule the OpenBao pod at its normal request (or
  temporarily lower it). If reschedule fails, free capacity then re-run / `--rollback`.
- **`cluster_addr`** — raft init requires it; the script sets it in the migrate config.
- **Unseal key custody** — the migrated raft data is sealed with the same static
  key; the script aborts if `openbao-unseal-key` is missing.

The manual procedure below documents what the script does, for auditing or one-off use.

## Names used below (adjust if your release/namespace differ)
- Release: `kleidia-platform`, namespace: `kleidia`
- StatefulSet / pod: `kleidia-platform-openbao` / `kleidia-platform-openbao-0`
- Data PVC: `data-kleidia-platform-openbao-0`
- Raft `node_id` (from `setNodeId` = pod name): `kleidia-platform-openbao-0`
- The **static seal key is unchanged** by migration, so the converted raft data
  auto-unseals with the existing `openbao-unseal-key` Secret.

---

## ⚠️ Before you start
1. **Confirm off-cluster custody** of `openbao-unseal-key` and `openbao-init-keys`.
   If migration goes wrong and you must rebuild, these are the only way back.
   ```bash
   kubectl -n kleidia get secret openbao-unseal-key  -o jsonpath='{.data}' # store the value securely, off-cluster
   kubectl -n kleidia get secret openbao-init-keys   -o jsonpath='{.data}' # store securely, off-cluster
   ```
2. **Snapshot/copy the data PVC** and keep it until the migration is verified.
   (Volume snapshot if your CSI supports it, or `kubectl cp` the `/openbao/data`
   tree out of a maintenance pod.)
3. **Test on a clone first.** Restore the PVC copy into a scratch namespace and
   rehearse the whole procedure there before touching production. An untested
   migration of your PKI root + secrets is not a plan.

---

## Procedure

### 1. Quiesce and stop OpenBao
```bash
# Optionally pause the app so nothing writes to OpenBao during migration.
kubectl -n kleidia scale deploy/backend deploy/frontend --replicas=0

# Stop the OpenBao server so the file store is quiescent.
kubectl -n kleidia scale statefulset/kleidia-platform-openbao --replicas=0
kubectl -n kleidia wait --for=delete pod/kleidia-platform-openbao-0 --timeout=120s
```

### 2. Run the migration in a maintenance pod
Create a `migrate.hcl` (source = file, destination = raft, **different paths**):
```hcl
storage_source "file" {
  path = "/openbao/data"
}
storage_destination "raft" {
  path    = "/openbao/raftdata"
  node_id = "kleidia-platform-openbao-0"
}
```

Launch a one-off pod that mounts the **same data PVC** and uses the OpenBao image:
```bash
kubectl -n kleidia apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: openbao-migrate
spec:
  restartPolicy: Never
  containers:
  - name: migrate
    image: quay.io/openbao/openbao:2.4.4   # match your deployed version / mirror
    command: ["sh","-c","sleep 3600"]
    volumeMounts:
    - { name: data, mountPath: /openbao/data }
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: data-kleidia-platform-openbao-0
EOF
kubectl -n kleidia wait --for=condition=Ready pod/openbao-migrate --timeout=120s

# Copy migrate.hcl in, then run the migration:
kubectl -n kleidia cp ./migrate.hcl openbao-migrate:/tmp/migrate.hcl
kubectl -n kleidia exec openbao-migrate -- sh -c '
  set -e
  mkdir -p /openbao/raftdata
  bao operator migrate -config=/tmp/migrate.hcl
  echo "migrate done"
'
```

### 3. Swap raft data into the path the chart expects (`/openbao/data`)
The raft config uses `path = "/openbao/data"`, so the converted data must live
there. Move the old file-format data aside (keep it until verified), then promote
the raft data:
```bash
kubectl -n kleidia exec openbao-migrate -- sh -c '
  set -e
  mkdir -p /openbao/_filebak
  # move file-format entries aside (everything except the new raftdata + _filebak)
  for e in /openbao/data/* ; do
    case "$e" in */raftdata|*/_filebak) ;; *) mv "$e" /openbao/_filebak/ ;; esac
  done
  mv /openbao/raftdata/* /openbao/data/
  rmdir /openbao/raftdata || true
  echo "swap done; old file data preserved under /openbao/_filebak until verified"
'
kubectl -n kleidia delete pod openbao-migrate
```
> Do **not** delete `/openbao/_filebak` yet — it is your in-place rollback until
> the raft pod is confirmed healthy.

### 4. Upgrade to the raft chart
```bash
helm upgrade kleidia-platform ./helm/kleidia-platform \
  --reuse-values --set storage.className=<your-storage-class>
kubectl -n kleidia rollout status statefulset/kleidia-platform-openbao --timeout=300s
```

### 5. Verify
```bash
kubectl -n kleidia exec kleidia-platform-openbao-0 -- bao status
#   Storage Type     raft
#   Sealed           false      (auto-unsealed by the static seal key)

kubectl -n kleidia exec kleidia-platform-openbao-0 -- sh -c 'BAO_TOKEN=<root> bao operator raft list-peers'
kubectl -n kleidia exec kleidia-platform-openbao-0 -- sh -c 'BAO_TOKEN=<root> bao secrets list'   # pki/, yubikeys/ present
# Take a test snapshot to prove the DR path now works:
kubectl -n kleidia exec kleidia-platform-openbao-0 -- sh -c 'BAO_TOKEN=<root> bao operator raft snapshot save /tmp/test.snap && ls -l /tmp/test.snap'
```

### 6. Resume and clean up
```bash
kubectl -n kleidia scale deploy/backend deploy/frontend --replicas=2
# Only after full verification: remove the preserved file-format data.
# (mount the PVC again in a throwaway pod and rm -rf /openbao/_filebak)
```

---

## Rollback
If the raft pod won't unseal or data looks wrong **before** you delete
`/openbao/_filebak`:
1. `helm rollback kleidia-platform` to the previous (file-storage) release.
2. In a maintenance pod, restore the file layout: `rm -rf /openbao/data/*` then
   `mv /openbao/_filebak/* /openbao/data/`.
3. Bring OpenBao back up on file storage and investigate before retrying.

If you have already deleted the preserved data, rebuild from your pre-migration
PVC copy (step 2 of "Before you start"), or as a last resort re-bootstrap and
re-import using the off-cluster init/recovery keys.
