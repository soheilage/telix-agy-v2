#!/usr/bin/env bash
# Pre-flight verification of the workshop project. Prints PASS/FAIL per check; exit 1 if any FAIL.
set -uo pipefail
source "$(dirname "$0")/00_vars.sh"

FAIL=0
ok()   { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; FAIL=1; }
warn() { echo "WARN  $1"; }

echo; echo "== APIs"
for API in aiplatform discoveryengine agentregistry storage cloudbuild artifactregistry logging cloudtrace; do
  if gcloud services list --enabled --project "${PROJECT_ID}" --format='value(config.name)' | grep -q "^${API}.googleapis.com$"; then
    ok "${API}.googleapis.com"; else bad "${API}.googleapis.com not enabled"; fi
done

echo; echo "== Buckets (must be in ${REGION})"
for BUCKET in "${STAGING_BUCKET}" "${WORKSHOP_BUCKET}"; do
  LOC="$(gcloud storage buckets describe "${BUCKET}" --format='value(location)' 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  if [[ "${LOC}" == "${REGION}" ]]; then ok "${BUCKET} (${LOC})"; else bad "${BUCKET} missing or in '${LOC}'"; fi
done

echo; echo "== Service agent bindings"
DISCOVERY_SA="service-${PROJECT_NUMBER}@gcp-sa-discoveryengine.iam.gserviceaccount.com"
if gcloud projects get-iam-policy "${PROJECT_ID}" --flatten='bindings[].members' \
     --filter="bindings.role=roles/aiplatform.user AND bindings.members=serviceAccount:${DISCOVERY_SA}" \
     --format='value(bindings.role)' | grep -q aiplatform; then
  ok "Discovery Engine SA has roles/aiplatform.user"; else bad "Discovery Engine SA lacks roles/aiplatform.user"; fi

echo; echo "== Gemini Enterprise app"
ADC_TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || true)"
[[ -n "${ADC_TOKEN}" ]] || bad "no Application Default Credentials -> gcloud auth application-default login"
GE_HOST="${GE_LOCATION}-discoveryengine.googleapis.com"; [[ "${GE_LOCATION}" == "global" ]] && GE_HOST="discoveryengine.googleapis.com"
if curl -sf -H "Authorization: Bearer ${ADC_TOKEN}" -H "x-goog-user-project: ${PROJECT_ID}" \
        "https://${GE_HOST}/v1/${GE_APP_RESOURCE}" >/dev/null; then
  ok "GE app ${GE_APP_RESOURCE}"
else
  bad "GE app not found: ${GE_APP_RESOURCE} (create in Console -> Gemini Enterprise, location ${GE_LOCATION})"
  echo "      existing apps in ${GE_LOCATION}:"
  curl -s -H "Authorization: Bearer ${ADC_TOKEN}" -H "x-goog-user-project: ${PROJECT_ID}" \
    "https://${GE_HOST}/v1/projects/${PROJECT_ID}/locations/${GE_LOCATION}/collections/default_collection/engines" \
    | python3 -c "import sys,json; [print('        -', e['name'].split('/')[-1], '(', e.get('displayName'), ')') for e in json.load(sys.stdin).get('engines', [])]" 2>/dev/null || true
fi

echo; echo "== Model availability: ${GEMINI_MODEL}"
probe_model() { # location -> http code
  local LOC="$1" HOST="${1}-aiplatform.googleapis.com"
  [[ "$1" == "global" ]] && HOST="aiplatform.googleapis.com"
  [[ "$1" == "eu" ]] && HOST="aiplatform.eu.rep.googleapis.com"   # EU jurisdictional (data-resident) endpoint
  [[ "$1" == "us" ]] && HOST="aiplatform.us.rep.googleapis.com"
  curl -s -o /dev/null -w '%{http_code}' -m 60 -X POST \
    -H "Authorization: Bearer ${ADC_TOKEN}" -H "x-goog-user-project: ${PROJECT_ID}" -H 'Content-Type: application/json' \
    "https://${HOST}/v1/projects/${PROJECT_ID}/locations/${LOC}/publishers/google/models/${GEMINI_MODEL}:generateContent" \
    -d '{"contents":[{"role":"user","parts":[{"text":"Reply with OK"}]}]}'
}
R_EU="$(probe_model eu)"; R_REG="$(probe_model "${REGION}")"; R_GLB="$(probe_model global)"
if [[ "${R_EU}" == "200" ]]; then ok "${GEMINI_MODEL} served on the EU data-resident endpoint (location=eu) -> MODEL_LOCATION=eu"
elif [[ "${R_REG}" == "200" ]]; then ok "${GEMINI_MODEL} served regionally in ${REGION} -> MODEL_LOCATION=${REGION}"
elif [[ "${R_GLB}" == "200" ]]; then warn "${GEMINI_MODEL} only on the global endpoint (eu=${R_EU}, ${REGION}=${R_REG}) -> global breaks EU residency; choose another model"
else bad "${GEMINI_MODEL} unavailable (eu=${R_EU}, ${REGION}=${R_REG}, global=${R_GLB})"; fi
[[ "${R_REG}" != "200" ]] && echo "      note: single-region ${REGION} returned ${R_REG}; this is expected for Gemini 3.x — use location=eu"

echo; echo "== Participants file"
if [[ -s "$(dirname "$0")/participants.txt" ]]; then
  ok "$(grep -cvE '^\s*(#|$)' "$(dirname "$0")/participants.txt") participants listed"
else warn "participants.txt missing/empty — run 02_iam_participants.sh once it is filled"; fi

echo; echo "== Scientific endpoints reachable from this machine"
for HOST in rest.uniprot.org/uniprotkb/P69905.json alphafold.ebi.ac.uk www.ebi.ac.uk string-db.org gtexportal.org www.proteinatlas.org pubchem.ncbi.nlm.nih.gov clinicaltrials.gov; do
  if curl -sf -o /dev/null -m 15 "https://${HOST}"; then ok "${HOST}"; else warn "${HOST} not reachable (check egress / proxy)"; fi
done

echo
[[ ${FAIL} -eq 0 ]] && echo "ALL REQUIRED CHECKS PASSED" || { echo "SOME CHECKS FAILED"; exit 1; }
