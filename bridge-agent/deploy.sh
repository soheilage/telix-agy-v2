#!/usr/bin/env bash
# Deploy the bridge agent to Vertex AI Agent Runtime (EU region) with agents-cli.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/common.sh"
export PATH="$HOME/.local/bin:$PATH"
need agents-cli

cd "${HERE}/${AGENT_PROJECT}" || { echo "Run ./build.sh first"; exit 1; }

echo "== Deploying ${AGENT_PROJECT} to Agent Runtime in ${REGION} (project ${PROJECT_ID})"
echo "   model ${GEMINI_MODEL} @ ${MODEL_LOCATION}"
# Note: agents-cli >= 1.12 has no --staging-bucket flag (Agent Runtime stages the build itself).
# --no-confirm-project avoids the interactive prompt; env vars make the container self-contained.
# Identity: the EU jurisdictional model endpoint (location=eu, aiplatform.eu.rep.googleapis.com) currently
# rejects tokens of the new per-agent "agent identity" principal with 401 UNAUTHENTICATED (verified Oct 2026),
# so run the agent as the project's compute service account instead (roles granted by facilitator script 03).
RUNTIME_SA="${RUNTIME_SA:-${PROJECT_NUMBER}-compute@developer.gserviceaccount.com}"
agents-cli deploy \
  --project "${PROJECT_ID}" \
  --region "${REGION}" \
  --no-confirm-project \
  --no-agent-identity \
  --service-account "${RUNTIME_SA}" \
  --env-vars "GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GOOGLE_CLOUD_LOCATION=${MODEL_LOCATION},GOOGLE_GENAI_USE_VERTEXAI=true,GEMINI_MODEL=${GEMINI_MODEL},UV_CACHE_DIR=/tmp/uv-cache" \
  "$@"

echo
echo "== deployment_metadata.json"
cat deployment_metadata.json 2>/dev/null || echo "(not written yet — if you used --no-wait, run: agents-cli deploy --status)"
echo
echo "DEPLOY OK → next: ./publish.sh"
