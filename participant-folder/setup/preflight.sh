#!/usr/bin/env bash
# Participant pre-flight check (researcher edition). Run from the workshop folder, or let the Antigravity agent run it.
# Prints PASS / WARN / FAIL lines. Exit 1 if anything required FAILs.
set -uo pipefail
export PATH="$HOME/.local/bin:$PATH"

: "${MODEL_LOCATION:=eu}"
: "${GEMINI_MODEL:=gemini-3.8-flash}"
FAIL=0
ok()   { echo "PASS  $1"; }
bad()  { echo "FAIL  $1"; FAIL=1; }
warn() { echo "WARN  $1"; }

echo "== Workspace"
[[ -f AGENTS.md ]] && ok "opened the workshop folder (AGENTS.md found)" || bad "AGENTS.md not found — open the telix-antigravity-workshop folder itself (File -> Open Folder)"
mkdir -p reports && ok "reports/ ready"

echo; echo "== Tools"
command -v gcloud >/dev/null && ok "gcloud $(gcloud version 2>/dev/null | head -1)" || bad "gcloud not installed: https://cloud.google.com/sdk/docs/install"
if command -v uv >/dev/null; then ok "uv $(uv --version)"; else
  warn "uv missing — installing (needed by the Science Skills)"
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 && command -v uv >/dev/null && ok "uv installed" || bad "uv install failed: https://docs.astral.sh/uv/"
fi
command -v python3 >/dev/null && ok "python $(python3 --version 2>&1)" || bad "python3 missing"

echo; echo "== Google Cloud sign-in"
ACCOUNT="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null)"
[[ -n "${ACCOUNT}" ]] && ok "signed in as ${ACCOUNT}" || bad "not signed in -> gcloud auth login"
gcloud auth application-default print-access-token >/dev/null 2>&1 && ok "application-default credentials" || bad "ADC missing -> gcloud auth application-default login"
PROJECT_ID="$(gcloud config get-value project 2>/dev/null)"
[[ -n "${PROJECT_ID}" ]] && ok "project ${PROJECT_ID}" || bad "no default project -> gcloud config set project <PROJECT_ID>"

if [[ -n "${PROJECT_ID}" ]]; then
  echo; echo "== Model ${GEMINI_MODEL} @ ${MODEL_LOCATION} (EU data-resident endpoint)"
  MHOST="aiplatform.eu.rep.googleapis.com"; [[ "${MODEL_LOCATION}" != "eu" ]] && MHOST="${MODEL_LOCATION}-aiplatform.googleapis.com"
  RESP="$(curl -s -o /dev/null -w '%{http_code}' -m 30 -X POST \
    -H "Authorization: Bearer $(gcloud auth application-default print-access-token 2>/dev/null)" -H "x-goog-user-project: ${PROJECT_ID}" -H 'Content-Type: application/json' \
    "https://${MHOST}/v1/projects/${PROJECT_ID}/locations/${MODEL_LOCATION}/publishers/google/models/${GEMINI_MODEL}:generateContent" \
    -d '{"contents":[{"role":"user","parts":[{"text":"Reply with OK"}]}]}')"
  [[ "${RESP}" == "200" ]] && ok "generateContent -> 200" || bad "generateContent -> HTTP ${RESP} (ask a facilitator: quota / permission / location)"
fi

echo; echo "== DeepMind Science Skills"
if [[ -f "$HOME/.gemini/config/plugins/science/skills/chembl_database/SKILL.md" ]]; then
  ok "Science plugin installed (~/.gemini/config/plugins/science/skills)"
elif ls -d "$HOME"/.agents/skills/*chembl* "$PWD"/.agents/skills/*chembl* 2>/dev/null | head -1 | awk 'END{exit NR==0}'; then
  ok "Science Skills installed via npx"
else
  bad "Science Skills not found — in Antigravity: Customizations -> Build with Google -> Science -> Add (then re-run)"
fi

echo; echo "== Scientific databases reachable"
for HOST in rest.uniprot.org/uniprotkb/P69905.json alphafold.ebi.ac.uk www.ebi.ac.uk string-db.org gtexportal.org www.proteinatlas.org pubchem.ncbi.nlm.nih.gov clinicaltrials.gov files.rcsb.org; do
  curl -sf -o /dev/null -m 15 "https://${HOST}" && ok "${HOST}" || warn "${HOST} unreachable (proxy / egress) — tell a facilitator"
done

echo
if [[ ${FAIL} -eq 0 ]]; then echo "READY FOR THE WORKSHOP"; else echo "PLEASE FIX THE FAIL ITEMS ABOVE (ask the Antigravity agent, or raise your hand)"; exit 1; fi
