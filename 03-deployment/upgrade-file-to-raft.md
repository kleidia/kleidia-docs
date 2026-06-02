# Upgrading an Existing Deployment (file storage → raft + native backups)

**Audience**: Operations Administrators
**Prerequisites**: Helm installed, cluster access (`kubectl`/`k0s`), an existing Kleidia deployment installed **before** the native-DR release
**Outcome**: OpenBao migrated from file storage to integrated raft, charts upgraded, and disaster-recovery backups verified working

This guide is for deployments installed **before** the native-DR release — i.e. ones
where OpenBao still runs on **file** storage. New installs already ship on raft with
native backups and need none of this.

**Why upgrade:** OpenBao on file storage has no snapshot API, so its backups never
actually run. Moving to integrated **raft** storage enables real disaster-recovery
snapshots, and the new charts add CloudNativePG WAL archiving (point-in-time
recovery) for the database.

> **TL;DR:** **1)** migrate OpenBao file→raft with the script → **2)** `helm upgrade`
> the charts → **3)** verify and confirm backups. **Migrate before upgrading** — that
> order matters: OpenBao cannot boot the raft config on file-format data.

This procedure has been validated end-to-end on a live deployment, including both
post-upgrade hook authentication paths.

---

## Before you start (5 minutes)

1. **Expect a brief OpenBao interruption.** The migration stops OpenBao for seconds
   to a couple of minutes while it converts the data. The app pods keep running;
   secret access pauses during the restart.

2. **Custody your keys off-cluster.** A raft snapshot is encrypted and is useless
   without the unseal key. Save these somewhere safe (password manager / offline):
   ```bash
   kubectl -n <ns> get secret openbao-unseal-key -o yaml   # the static seal key
   kubectl -n <ns> get secret openbao-init-keys  -o yaml   # root + recovery keys, if still present
   ```

3. **Confirm the upgrade can authenticate.** After first-time bootstrap, the upgrade
   hook authenticates with the `openbao-helm-approle` credential. Verify its
   `role_id` is not empty:
   ```bash
   kubectl -n <ns> get secret openbao-helm-approle -o jsonpath='{.data.role_id}' | base64 -d | wc -c
   # expect ~36. If it prints 0, stop and contact support — the admin credential is
   # corrupted (a bug fixed in this release, but it cannot be repaired retroactively
   # without break-glass root access).
   ```

4. **Do not downgrade OpenBao.** Keep the OpenBao image at your current version or
   newer across the upgrade — raft data written by a newer OpenBao will not load on
   an older binary. Check your current version:
   ```bash
   kubectl -n <ns> get statefulset kleidia-platform-openbao -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

5. **Have a current database backup** in addition to the migration's own backups.

---

## Step 1 — Migrate OpenBao from file storage to raft

Download the migration script and run it against your cluster:

```bash
# Fetch the script:
curl -fsSLO https://raw.githubusercontent.com/kleidia/kleidia-docs/main/scripts/openbao-file-to-raft-migrate.sh
chmod +x openbao-file-to-raft-migrate.sh

# standard kubectl:
KUBECTL="kubectl" NAMESPACE=<ns> ./openbao-file-to-raft-migrate.sh

# k0s:
KUBECTL="sudo k0s kubectl" NAMESPACE=<ns> ./openbao-file-to-raft-migrate.sh

# add -y to skip the confirmation prompt
```

The script:
- pre-flight checks + is idempotent (no-op if already on raft),
- backs up the data PVC + the OpenBao ConfigMap + the unseal-key secret,
- stops OpenBao, runs `bao operator migrate` (file → raft) in a maintenance pod,
- switches the storage config and restarts OpenBao,
- verifies it comes back **unsealed on raft**.

It **auto-reverts to file storage** on any failure and has a `--rollback` mode. Your
old file-format data is preserved at `PVC:/openbao/data/_filebak` until you delete it.

Full detail and the manual equivalent: [OpenBao raft migration reference](../04-operations/openbao-raft-migration.md).

---

## Step 2 — `helm upgrade` to the new charts

Upgrade the three releases, **platform first**, with the same values you installed with:

```bash
helm upgrade kleidia-platform ./helm/kleidia-platform -f <your-values.yaml>
helm upgrade kleidia-data     ./helm/kleidia-data     -f <your-values.yaml>
helm upgrade kleidia-services ./helm/kleidia-services -f <your-values.yaml>
```

This brings the new images plus:
- the `ha.raft` OpenBao configuration (which reads the data you just migrated),
- CloudNativePG `barmanObjectStore` + continuous WAL archiving (point-in-time recovery),
- the consolidated backup job and the working OpenBao raft-snapshot path.

The OpenBao setup hook re-runs as part of the upgrade. It is idempotent on the
post-bootstrap path: it re-applies service policies, tolerates the operations it
isn't permitted to repeat, and **never overwrites your unseal key or admin
credential**. `helm upgrade` should finish with `STATUS: deployed`.

> If `helm upgrade` ever reports a hook failure while OpenBao is otherwise healthy,
> simply re-run the upgrade. The data and credentials are preserved by design.

---

## Step 3 — Verify, then confirm native backups

Verify the platform:
```bash
kubectl -n <ns> exec <openbao-pod> -c openbao -- bao status
#   Storage Type   raft
#   Sealed         false

kubectl -n <ns> get cluster.postgresql.cnpg.io/kleidia-db \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} {end}'
#   ... ContinuousArchiving=True ...
```

Confirm backups onto the native path:
- Open **Admin → Backup** in the UI and **re-save your S3 settings**. Your existing
  S3 configuration carries over (it lives in OpenBao); re-saving (re)applies it to
  the new mechanism — wiring CNPG `barmanObjectStore` and the OpenBao raft-snapshot
  job.
- **Take one test backup, then a test restore**, before relying on it. See
  [Backups and Restore](../04-operations/backups-and-restore.md).

> First-backup tip (idle databases): enable archiving, confirm a WAL segment has
> been archived (`pg_stat_archiver.last_archived_wal` advances), *then* take the
> first base backup — otherwise that backup's starting WAL may not yet be in object
> storage and the backup won't be restorable. The chart sets `archive_timeout` to
> make idle clusters archive automatically.

---

## If something goes wrong

| Symptom | Action |
|---------|--------|
| Migration failed / OpenBao won't unseal on raft | `./openbao-file-to-raft-migrate.sh --rollback` (restores file storage from `_filebak`) |
| `helm upgrade` reports a hook failure, OpenBao healthy | Re-run the upgrade — data and credentials are preserved |
| Pod won't schedule after migration (tight node) | Free CPU (the script suspends the backup CronJob to avoid a slot race) or temporarily lower the OpenBao CPU request, then retry |
| Need admin but `openbao-init-keys` was deleted at bootstrap | Restore it from your off-cluster custody (Before-you-start step 2) |

---

## What changed under the hood (reference)

- OpenBao: `storage "file"` → integrated `raft` (HA-capable; single replica by default).
- Unseal key is now **preserved across upgrades** (was regenerated each upgrade, which re-sealed OpenBao).
- AppRole credentials are **never overwritten with empty values** (prevented a permanent admin lockout).
- CNPG: `barmanObjectStore` + WAL archiving + `archive_timeout` for PITR.
- Backups consolidated onto native paths: CNPG for the database, OpenBao raft snapshots for secrets, both to your S3.
