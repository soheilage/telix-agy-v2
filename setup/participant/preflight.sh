#!/usr/bin/env bash
# Participant pre-flight check. Run from the repo root (or let the Antigravity agent run it).
# Prints PASS / WARN / FAIL lines. Exit 1 if anything required FAILs.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

: "${REGION:=europe-west4}"
: "${MODEL_LOCATION:=eu}"
: "${GEMINI_MODEL:=gemini-3.8-flash}"
FAIL=0
ok()   { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; FAIL=1; }
warn() { echo "WARN  $1"; }

echo "== Tools"
command -v gcloud >/dev/null && ok "gcloud $(gcloud version 2>/dev/null | head -1)" || bad "gcloud not installed: https://cloud.google.com/sdk/docs/install"
command -v uv >/dev/null && ok "uv $(uv --version)" || bad "uv missing -> run setup/participant/install_prereqs.sh"
command -v python3 >/dev/null && ok "python $(python3 --version 2>&1)" || bad "python3 missing"
if command -v agents-cli >/dev/null; then
  ACLI_VER="$(agents-cli --version 2>/dev/null | awk '{print $NF}')"
  ACLI_MAJMIN="$(echo "${ACLI_VER}" | awk -F. '{printf "%d%03d", $1, $2}')"
  if [[ "${ACLI_MAJMIN:-0}" -ge 1012 ]]; then ok "agents-cli ${ACLI_VER}"; else bad "agents-cli ${ACLI_VER} too old -> uv tool install --upgrade google-agents-cli (need >= 1.12)"; fi
else bad "agents-cli missing -> uv tool install google-agents-cli && agents-cli setup"; fi
command -v node >/dev/null && ok "node $(node --version)" || warn "node missing (only needed for npx skills add)"
command -v git >/dev/null && ok "git" || bad "git missing"

echo; echo "== Google Cloud auth"
ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)"
[[ -n "${ACCOUNT}" ]] && ok "signed in as ${ACCOUNT}" || bad "not signed in -> gcloud auth login"
gcloud auth application-default print-access-token >/dev/null 2>&1 && ok "application-default credentials" || bad "ADC missing -> gcloud auth application-default login"
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
[[ -n "${PROJECT_ID}" ]] && ok "project ${PROJECT_ID}" || bad "no default project -> gcloud config set project <PROJECT_ID>"

if [[ -n "${PROJECT_ID}" ]]; then
  echo; echo "== Permissions in ${PROJECT_ID}"
  gcloud services list --enabled --project "${PROJECT_ID}" --format='value(config.name)' 2>/dev/null | grep -q aiplatform && ok "Vertex AI API enabled" || bad "cannot see aiplatform API (permission or not enabled)"
  for B in "gs://${PROJECT_ID}-adk-staging" "gs://${PROJECT_ID}-workshop"; do
    gcloud storage ls "${B}" >/dev/null 2>&1 && ok "access to ${B}" || bad "no access to ${B}"
  done
  echo; echo "== Model ${GEMINI_MODEL} @ ${MODEL_LOCATION}"
  MHOST="${MODEL_LOCATION}-aiplatform.googleapis.com"; [[ "${MODEL_LOCATION}" == "eu" ]] && MHOST="aiplatform.eu.rep.googleapis.com"; [[ "${MODEL_LOCATION}" == "global" ]] && MHOST="aiplatform.googleapis.com"
  RESP="$(curl -s -o /dev/null -w '%{http_code}' -m 30 -X POST \
    -H "Authorization: Bearer $(gcloud auth application-default print-access-token 2>/dev/null)" -H "x-goog-user-project: ${PROJECT_ID}" -H 'Content-Type: application/json' \
    "https://${MHOST}/v1/projects/${PROJECT_ID}/locations/${MODEL_LOCATION}/publishers/google/models/${GEMINI_MODEL}:generateContent" \
    -d '{"contents":[{"role":"user","parts":[{"text":"Reply with OK"}]}]}')"
  [[ "${RESP}" == "200" ]] && ok "generateContent -> 200 (EU data-resident endpoint)" || bad "generateContent -> HTTP ${RESP} (quota/permission/location)"
fi

echo; echo "== Antigravity skills"
if ls "$HOME"/.gemini/*/skills 2>/dev/null | grep -q google-agents-cli || ls "$HOME"/.agents/skills 2>/dev/null | grep -q google-agents-cli \
   || ls "$HOME"/.config/skills 2>/dev/null | grep -q google-agents-cli; then
  ok "google-agents-cli-* skills found"
else
  warn "google-agents-cli-* skills not found in a known location; in Antigravity open the skills list and check, or re-run: uvx google-agents-cli setup"
fi
if [[ -f "$HOME/.gemini/config/plugins/science/skills/chembl_database/SKILL.md" ]]; then
  ok "DeepMind Science Skills (Antigravity Science plugin) at ~/.gemini/config/plugins/science/skills"
elif ls -d "$HOME"/.agents/skills/*chembl* "$PWD"/.agents/skills/*chembl* 2>/dev/null | head -1 | awk 'END{exit NR==0}'; then
  ok "DeepMind Science Skills installed via npx"
else
  warn "DeepMind Science Skills not found — enable the Science plugin in Antigravity (onboarding page 'Build with Google', or Customizations -> Build with Google -> Science -> Add)"
fi

echo; echo "== Scientific endpoints"
for HOST in rest.uniprot.org/uniprotkb/P69905.json alphafold.ebi.ac.uk www.ebi.ac.uk string-db.org gtexportal.org pubchem.ncbi.nlm.nih.gov clinicaltrials.gov; do
  curl -sf -o /dev/null -m 15 "https://${HOST}" && ok "${HOST}" || warn "${HOST} unreachable (proxy / egress)"
done

echo
if [[ ${FAIL} -eq 0 ]]; then echo "READY FOR THE WORKSHOP"; else echo "PLEASE FIX THE FAIL ITEMS ABOVE (ask the Antigravity agent to help)"; exit 1; fi
