#!/usr/bin/env bash
# Grant workshop participants the IAM roles they need.
# Reads emails (one per line, '#' comments allowed) from participants.txt next to this script.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/00_vars.sh"

PARTICIPANTS_FILE="${1:-${HERE}/participants.txt}"
[[ -f "${PARTICIPANTS_FILE}" ]] || { echo "Missing ${PARTICIPANTS_FILE} (see participants.txt.example)"; exit 1; }

PROJECT_ROLES=(
  roles/aiplatform.user
  roles/discoveryengine.editor
  roles/iam.serviceAccountUser
  roles/logging.viewer
  roles/cloudtrace.user
  roles/serviceusage.serviceUsageConsumer
)

grep -vE '^\s*(#|$)' "${PARTICIPANTS_FILE}" | while read -r EMAIL; do
  echo "== ${EMAIL}"
  for ROLE in "${PROJECT_ROLES[@]}"; do
    gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
      --member="user:${EMAIL}" --role="${ROLE}" --condition=None --quiet >/dev/null
    echo "   + ${ROLE}"
  done
  for BUCKET in "${STAGING_BUCKET}" "${WORKSHOP_BUCKET}"; do
    gcloud storage buckets add-iam-policy-binding "${BUCKET}" \
      --member="user:${EMAIL}" --role=roles/storage.objectAdmin --quiet >/dev/null
    echo "   + roles/storage.objectAdmin on ${BUCKET}"
  done
done

cat <<EOF

IAM done. Still required OUTSIDE IAM for every participant:
  * Gemini Enterprise user licence  (Console -> Gemini Enterprise -> Licences)
  * Antigravity / Agent Platform licence for IDE sign-in
EOF
