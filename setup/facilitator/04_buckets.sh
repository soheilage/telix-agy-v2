#!/usr/bin/env bash
# Create the EU buckets used by the workshop (idempotent).
set -euo pipefail
source "$(dirname "$0")/00_vars.sh"

for BUCKET in "${STAGING_BUCKET}" "${WORKSHOP_BUCKET}"; do
  if gcloud storage buckets describe "${BUCKET}" >/dev/null 2>&1; then
    echo "exists: ${BUCKET}"
  else
    gcloud storage buckets create "${BUCKET}" \
      --project "${PROJECT_ID}" --location "${REGION}" \
      --uniform-bucket-level-access --public-access-prevention
    echo "created: ${BUCKET} in ${REGION}"
  fi
done
