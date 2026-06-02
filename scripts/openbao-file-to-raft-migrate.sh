#!/usr/bin/env bash
# =============================================================================
# OpenBao migration: file storage -> integrated Raft (in place)
# =============================================================================
# Converts a Kleidia OpenBao deployment from `storage "file"` to `storage "raft"`
# so that raft snapshots (the supported DR backup) work. File storage has no
# snapshot API, so backups on file storage silently fail.
#
# This is NOT a hot config flip: OpenBao cannot read file-backed data under a
# raft config. The conversion is done offline with `bao operator migrate` while
# the server is stopped, then the storage stanza is switched and OpenBao is
# restarted (the static seal auto-unseals the converted data).
#
# What it does, in order:
#   0. Pre-flight: detect current storage, find image/PVC/seal secret, idempotency.
#   1. Backup: hot tar of the data PVC + the OpenBao ConfigMap + the unseal secret.
#   2. Stop OpenBao (scale StatefulSet to 0).
#   3. Maintenance pod: `bao operator migrate` (file -> raft), keep old data in
#      /openbao/data/_filebak as an in-place rollback.
#   4. Patch the ConfigMap storage stanza file -> raft (+ node_id).
#   5. Start OpenBao, wait until raft + unsealed; verify.
#   On failure during 2-5 it auto-reverts to file storage and restarts.
#
# Safe to re-run: if storage is already raft, it exits 0.
#
# Usage:
#   ./openbao-file-to-raft-migrate.sh [-y] [--rollback]
# Environment overrides (defaults target a standard kleidia deploy):
#   KUBECTL          kubectl invocation        (default: kubectl)
#   NAMESPACE        deploy namespace          (default: kleidia)
#   RELEASE          openbao release prefix    (default: kleidia-platform-openbao)
#   CONFIG_KEY       ConfigMap HCL key         (default: extraconfig-from-values.hcl)
#   BACKUP_DIR       local backup dir          (default: ./openbao-migration-backup-<pid>)
#   CONFIRM          ask|yes                   (default: ask; -y sets yes)
#
# Example (k0s):
#   KUBECTL="sudo k0s kubectl" ./openbao-file-to-raft-migrate.sh -y
# =============================================================================
set -euo pipefail

KUBECTL="${KUBECTL:-kubectl}"
NAMESPACE="${NAMESPACE:-kleidia}"
RELEASE="${RELEASE:-kleidia-platform-openbao}"
CONFIG_KEY="${CONFIG_KEY:-extraconfig-from-values.hcl}"
CONFIRM="${CONFIRM:-ask}"
ROLLBACK_MODE="false"

STS="$RELEASE"
POD="${RELEASE}-0"
NODE_ID="${RELEASE}-0"
CONFIGMAP="${RELEASE}-config"
DATA_PVC="data-${RELEASE}-0"
UNSEAL_SECRET="openbao-unseal-key"
BACKUP_DIR="${BACKUP_DIR:-./openbao-migration-backup-$$}"

for arg in "$@"; do
  case "$arg" in
    -y|--yes) CONFIRM="yes" ;;
    --rollback) ROLLBACK_MODE="true" ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

K() { $KUBECTL -n "$NAMESPACE" "$@"; }
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '    \033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '    \033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- read the current OpenBao HCL config -------------------------------------
get_config() { K get configmap "$CONFIGMAP" -o "jsonpath={.data.${CONFIG_KEY//./\\.}}"; }

storage_type() {
  # crude but robust: which storage stanza is present
  local c; c="$(get_config 2>/dev/null || true)"
  if   printf '%s' "$c" | grep -q 'storage "raft"'; then echo raft
  elif printf '%s' "$c" | grep -q 'storage "file"'; then echo file
  else echo unknown; fi
}

wait_pod_gone() {
  log "Waiting for $POD to terminate..."
  K wait --for=delete "pod/$POD" --timeout=180s 2>/dev/null || true
  for _ in $(seq 1 60); do K get "pod/$POD" >/dev/null 2>&1 || { ok "stopped"; return 0; }; sleep 2; done
  die "pod $POD did not terminate"
}

wait_pod_ready() {
  log "Waiting for $POD to become Ready..."
  K wait --for=condition=Ready "pod/$POD" --timeout=240s || die "pod $POD not Ready (check: $KUBECTL -n $NAMESPACE logs $POD)"
  ok "pod Ready"
}

bao_status_json() { K exec "$POD" -c openbao -- sh -c 'bao status -format=json 2>/dev/null || vault status -format=json 2>/dev/null' 2>/dev/null || true; }

# --- ConfigMap storage stanza rewrite (file <-> raft) ------------------------
# Replaces the whole `storage "<x>" { ... }` block. Uses awk so we don't depend
# on the exact internal whitespace.
rewrite_storage() {  # $1=target (raft|file)
  local target="$1" cur new
  cur="$(get_config)" || die "cannot read ConfigMap $CONFIGMAP"
  new="$(printf '%s' "$cur" | awk -v target="$target" -v node="$NODE_ID" '
    BEGIN{instorage=0}
    /storage "(file|raft)" *{/ && instorage==0 {
      instorage=1; depth=gsub(/{/,"{")-gsub(/}/,"}");
      if (target=="raft") {
        print "storage \"raft\" {";
        print "  path = \"/openbao/data\"";
        print "  node_id = \"" node "\"";
      } else {
        print "storage \"file\" {";
        print "  path = \"/openbao/data\"";
      }
      if (depth<=0){instorage=0; print "}"}
      next
    }
    instorage==1 {
      depth+=gsub(/{/,"{")-gsub(/}/,"}");
      if (depth<=0){instorage=0; print "}"}
      next
    }
    {print}
  ')"
  printf '%s' "$new" | grep -q "storage \"$target\"" || die "storage rewrite to $target failed"
  # Build a JSON merge patch that changes ONLY the data key (preserves the
  # ConfigMap's labels/helm-ownership). jq if present, else python3.
  local payload=""
  if command -v jq >/dev/null 2>&1; then
    payload="$(printf '%s' "$new" | jq -Rs --arg k "$CONFIG_KEY" '{data:{($k):.}}')"
  elif command -v python3 >/dev/null 2>&1; then
    payload="$(printf '%s' "$new" | python3 -c 'import json,sys; print(json.dumps({"data":{sys.argv[1]:sys.stdin.read()}}))' "$CONFIG_KEY")"
  else
    die "need jq or python3 to build the ConfigMap patch"
  fi
  [ -n "$payload" ] || die "failed to build ConfigMap patch payload"
  printf '%s' "$payload" | K patch configmap "$CONFIGMAP" --type merge --patch-file=/dev/stdin >/dev/null
  ok "ConfigMap storage stanza -> $target"
}

# --- maintenance pod that mounts the data PVC --------------------------------
run_maint_pod() {  # $1=name  $2=shell-script
  local name="$1" script="$2"
  K delete pod "$name" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  # Match the OpenBao pod's security context so created files have the right
  # ownership (and so it's admissible under a restricted PodSecurity namespace).
  local U G F
  U="$(K get statefulset "$STS" -o jsonpath='{.spec.template.spec.securityContext.runAsUser}' 2>/dev/null)"; U="${U:-100}"
  G="$(K get statefulset "$STS" -o jsonpath='{.spec.template.spec.securityContext.runAsGroup}' 2>/dev/null)"; G="${G:-1000}"
  F="$(K get statefulset "$STS" -o jsonpath='{.spec.template.spec.securityContext.fsGroup}' 2>/dev/null)"; F="${F:-1000}"
  # reuse the OpenBao image + a writable scratch volume, run the script, exit.
  cat <<YAML | K apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata: { name: $name, labels: { app: openbao-migrate } }
spec:
  restartPolicy: Never
  securityContext: { runAsUser: $U, runAsGroup: $G, fsGroup: $F, runAsNonRoot: true }
  containers:
  - name: migrate
    image: $IMAGE
    command: ["sh","-c"]
    args:
    - |
$(printf '%s\n' "$script" | sed 's/^/        /')
    volumeMounts:
    - { name: data, mountPath: /openbao/data }
    - { name: scratch, mountPath: /scratch }
  volumes:
  - name: data
    persistentVolumeClaim: { claimName: $DATA_PVC }
  - name: scratch
    emptyDir: {}
YAML
  K wait --for=condition=Ready "pod/$name" --timeout=120s >/dev/null 2>&1 || true
  # wait for completion
  for _ in $(seq 1 150); do
    local ph; ph="$(K get pod "$name" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [ "$ph" = "Succeeded" ] && break
    [ "$ph" = "Failed" ] && { K logs "$name" || true; die "maintenance pod $name failed"; }
    sleep 2
  done
  K logs "$name" 2>/dev/null || true
}

# =============================================================================
# ROLLBACK MODE
# =============================================================================
if [ "$ROLLBACK_MODE" = "true" ]; then
  log "ROLLBACK: reverting OpenBao to file storage from _filebak"
  IMAGE="$(K get statefulset "$STS" -o jsonpath='{.spec.template.spec.containers[0].image}')"
  K scale statefulset "$STS" --replicas=0; wait_pod_gone
  run_maint_pod openbao-rollback '
set -e
if [ ! -d /openbao/data/_filebak ]; then echo "no _filebak to restore"; exit 1; fi
cd /openbao/data
for e in * ; do [ "$e" = "_filebak" ] && continue; rm -rf "$e"; done
mv _filebak/* /openbao/data/ && rmdir _filebak || true
echo ROLLBACK_DATA_OK'
  K delete pod openbao-rollback --ignore-not-found >/dev/null 2>&1 || true
  rewrite_storage file
  K scale statefulset "$STS" --replicas=1; wait_pod_ready
  log "Rollback complete"; bao_status_json | grep -iE 'storage|sealed' || true
  exit 0
fi

# =============================================================================
# 0. PRE-FLIGHT
# =============================================================================
log "Pre-flight checks"
K version >/dev/null 2>&1 || die "kubectl ('$KUBECTL') cannot reach the cluster"
K get statefulset "$STS" >/dev/null 2>&1 || die "StatefulSet $STS not found in ns $NAMESPACE"

ST="$(storage_type)"
case "$ST" in
  raft)    ok "OpenBao is already on raft storage — nothing to do."; exit 0 ;;
  file)    ok "current storage: file (will migrate to raft)" ;;
  *)       die "could not determine current storage type from ConfigMap $CONFIGMAP" ;;
esac

IMAGE="$(K get statefulset "$STS" -o jsonpath='{.spec.template.spec.containers[0].image}')"
[ -n "$IMAGE" ] || die "could not read OpenBao image from StatefulSet"
ok "OpenBao image: $IMAGE"
ok "node_id: $NODE_ID   data PVC: $DATA_PVC"

if K get secret "$UNSEAL_SECRET" >/dev/null 2>&1; then
  ok "unseal-key secret '$UNSEAL_SECRET' present (required to unseal migrated data)"
else
  die "unseal-key secret '$UNSEAL_SECRET' NOT found — a raft snapshot is encrypted and unrestorable without it. Aborting."
fi

if [ "$CONFIRM" != "yes" ]; then
  printf '\nThis STOPS OpenBao (brief downtime) and converts %s storage file->raft in place.\nBackups go to %s. Type "yes" to proceed: ' "$STS" "$BACKUP_DIR"
  read -r ans; [ "$ans" = "yes" ] || { echo "aborted."; exit 1; }
fi

# =============================================================================
# 1. BACKUP (rollback insurance)
# =============================================================================
log "Backing up to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"; chmod 700 "$BACKUP_DIR"
K get configmap "$CONFIGMAP" -o yaml > "$BACKUP_DIR/configmap.yaml" && ok "saved ConfigMap"
K get secret "$UNSEAL_SECRET" -o yaml > "$BACKUP_DIR/unseal-secret.yaml" && ok "saved unseal secret"
log "Hot-copying data PVC (this may take a moment)"
K exec "$POD" -c openbao -- tar czf - -C /openbao data > "$BACKUP_DIR/openbao-data.tgz" 2>/dev/null \
  && ok "saved data PVC tarball ($(wc -c < "$BACKUP_DIR/openbao-data.tgz") bytes)" \
  || warn "hot data backup skipped (pod busy); _filebak on-PVC backup still applies"

# =============================================================================
# 2-5. MIGRATE  (auto-revert to file on failure)
# =============================================================================
ORIG_REPLICAS="$(K get statefulset "$STS" -o jsonpath='{.spec.replicas}')"
CRITICAL=0
on_err() {
  warn "migration failed — attempting auto-revert to file storage"
  rewrite_storage file 2>/dev/null || warn "could not revert ConfigMap; restore manually from $BACKUP_DIR/configmap.yaml"
  K scale statefulset "$STS" --replicas="${ORIG_REPLICAS:-1}" >/dev/null 2>&1 || true
  resume_cronjob 2>/dev/null || true
  warn "If the pod won't start (or data was swapped), run: $0 --rollback"
}
resume_cronjob() { :; }  # redefined in the critical section once the cronjob name is known
# EXIT-based guard: any abnormal exit (die/exit, set -e) while CRITICAL=1 reverts.
# (An ERR trap would NOT fire on die's explicit `exit`.)
trap 'rc=$?; [ "${CRITICAL:-0}" = 1 ] && on_err; exit $rc' EXIT

CRITICAL=1
# Suspend the backup CronJob during the migration: when OpenBao stops it frees
# its CPU slot, and on a tight node a Pending backup pod can grab that slot and
# block OpenBao from rescheduling. Resumed in on_err and on success.
BACKUP_CRONJOB="${BACKUP_CRONJOB:-kleidia-backup}"
CRON_SUSPENDED=0
if K get cronjob "$BACKUP_CRONJOB" >/dev/null 2>&1; then
  K patch cronjob "$BACKUP_CRONJOB" -p '{"spec":{"suspend":true}}' >/dev/null 2>&1 && { CRON_SUSPENDED=1; ok "suspended CronJob $BACKUP_CRONJOB during migration"; }
fi
resume_cronjob() { [ "$CRON_SUSPENDED" = 1 ] && K patch cronjob "$BACKUP_CRONJOB" -p '{"spec":{"suspend":false}}' >/dev/null 2>&1 || true; }

log "Stopping OpenBao"
K scale statefulset "$STS" --replicas=0; wait_pod_gone

log "Migrating storage file -> raft (bao operator migrate)"
run_maint_pod openbao-migrate "
set -e
cat > /tmp/migrate.hcl <<EOF
storage_source \"file\" {
  path = \"/openbao/data\"
}
storage_destination \"raft\" {
  path = \"/scratch/raft\"
  node_id = \"$NODE_ID\"
}
# raft storage requires a cluster_addr to initialize; offline migrate only needs
# a syntactically valid value (the real one comes from the server config at boot).
cluster_addr = \"https://127.0.0.1:8201\"
EOF
mkdir -p /scratch/raft
bao operator migrate -config=/tmp/migrate.hcl
test -e /scratch/raft/vault.db || { echo 'migrate produced no vault.db'; exit 1; }
# swap: keep old file data under _filebak, promote raft data to /openbao/data
mkdir -p /openbao/data/_filebak
cd /openbao/data
for e in * ; do [ \"\$e\" = '_filebak' ] && continue; mv \"\$e\" _filebak/; done
mv /scratch/raft/* /openbao/data/
echo MIGRATION_OK"
K logs openbao-migrate 2>/dev/null | grep -q MIGRATION_OK || die "migration did not complete (data left intact under file layout)"
K delete pod openbao-migrate --ignore-not-found >/dev/null 2>&1 || true
ok "data converted to raft (old file data preserved in PVC:/openbao/data/_filebak)"

log "Switching ConfigMap storage stanza to raft"
rewrite_storage raft

log "Starting OpenBao on raft"
K scale statefulset "$STS" --replicas="${ORIG_REPLICAS:-1}"; wait_pod_ready

# verify
sleep 3
STATUS="$(bao_status_json)"
S_TYPE="$(printf '%s' "$STATUS" | grep -o '"storage_type"[^,]*' | head -1)"
SEALED="$(printf '%s' "$STATUS" | grep -oE '"sealed": *[a-z]+' | head -1)"
printf '%s' "$S_TYPE" | grep -q raft || die "OpenBao did not come up on raft ($S_TYPE). Run: $0 --rollback"
echo "$SEALED" | grep -q 'false' || warn "OpenBao reports sealed — check the static unseal key / pod logs"
resume_cronjob
CRITICAL=0; trap - EXIT

log "MIGRATION COMPLETE"
ok "storage: raft, $SEALED"
ok "rollback (if needed): $0 --rollback   (old data: PVC:/openbao/data/_filebak)"
ok "once verified healthy you may delete _filebak to reclaim space"
echo
echo "Next: take a raft snapshot to confirm DR works, e.g.:"
echo "  $KUBECTL -n $NAMESPACE exec $POD -c openbao -- sh -c 'VAULT_TOKEN=<token> bao operator raft snapshot save /tmp/s.snap && ls -l /tmp/s.snap'"
