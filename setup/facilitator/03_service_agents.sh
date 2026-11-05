#!/usr/bin/env bash
# Grant the Google-managed service agents and the default compute SA the roles
# needed for Agent Runtime deployments and Gemini Enterprise -> agent calls.
set -euo pipefail
source "$(dirname "$0")/00_vars.sh"

DISCOVERY_SA="service-${PROJECT_NUMBER}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
AIPLATFORM_SA="service-${PROJECT_NUMBER}@gcp-sa-aiplatform.iam.gserviceaccount.com"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

# Service agents are created lazily; trigger creation explicitly.
gcloud beta services identity create --service=discoveryengine.googleapis.com --project "${PROJECT_ID}" >/dev/null 2>&1 || true
gcloud beta services identity create --service=aiplatform.googleapis.com --project "${PROJECT_ID}" >/dev/null 2>&1 || true

bind() { # member role
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" --member="$1" --role="$2" --condition=None --quiet >/dev/null
  echo "   + $2 -> $1"
}

echo "== Discovery Engine service agent (Gemini Enterprise calls Agent Runtime)"
bind "serviceAccount:${DISCOVERY_SA}" roles/aiplatform.user

echo "== Vertex AI service agent"
bind "serviceAccount:${AIPLATFORM_SA}" roles/aiplatform.serviceAgent

echo "== Default compute SA (runtime identity of deployed agents)"
# The SA is created when the Compute API is enabled; it can take a minute to appear.
for i in 1 2 3 4 5 6; do
  gcloud iam service-accounts describe "${COMPUTE_SA}" --project "${PROJECT_ID}" >/dev/null 2>&1 && break
  echo "   waiting for ${COMPUTE_SA} to exist (enable compute.googleapis.com) ..."; sleep 20
done
if gcloud iam service-accounts describe "${COMPUTE_SA}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  bind "serviceAccount:${COMPUTE_SA}" roles/aiplatform.user
  bind "serviceAccount:${COMPUTE_SA}" roles/logging.logWriter
  bind "serviceAccount:${COMPUTE_SA}" roles/cloudtrace.agent
  gcloud storage buckets add-iam-policy-binding "${STAGING_BUCKET}" \
    --member="serviceAccount:${COMPUTE_SA}" --role=roles/storage.objectViewer --quiet >/dev/null
  echo "   + roles/storage.objectViewer on ${STAGING_BUCKET}"
else
  echo "   !! ${COMPUTE_SA} still missing — run 01_enable_apis.sh, wait a minute, re-run this script"
fi

echo "== Agent Runtime (Reasoning Engine) service agent"
RE_SA="service-${PROJECT_NUMBER}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"
gcloud beta services identity create --service=aiplatform.googleapis.com --project "${PROJECT_ID}" >/dev/null 2>&1 || true
if gcloud projects get-iam-policy "${PROJECT_ID}" --format=json | grep -q "${RE_SA}"; then
  echo "   ${RE_SA} already bound"
else
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" --member="serviceAccount:${RE_SA}" \
    --role=roles/aiplatform.reasoningEngineServiceAgent --condition=None --quiet >/dev/null 2>&1 \
    && echo "   + roles/aiplatform.reasoningEngineServiceAgent -> ${RE_SA}" \
    || echo "   (service agent ${RE_SA} not created yet — it is created automatically on first deploy)"
fi

echo "Service agent bindings done."
