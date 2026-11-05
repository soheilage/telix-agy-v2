#!/usr/bin/env bash
# Register the deployed bridge agent in the Telix Gemini Enterprise app (EU).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "${HERE}/common.sh"
export PATH="$HOME/.local/bin:$PATH"
need agents-cli

cd "${HERE}/${AGENT_PROJECT}" || { echo "Run ./build.sh and ./deploy.sh first"; exit 1; }
[[ -f deployment_metadata.json ]] || { echo "deployment_metadata.json missing — deployment not finished? try: agents-cli deploy --status"; exit 1; }

echo "== Publishing to Gemini Enterprise app ${GE_APP_RESOURCE}"
agents-cli publish gemini-enterprise \
  --registration-type adk \
  --gemini-enterprise-app-id "${GE_APP_RESOURCE}" \
  --project-id "${PROJECT_ID}" \
  --project-number "${PROJECT_NUMBER}" \
  --display-name "${DISPLAY_NAME}" \
  --description "${DESCRIPTION}" \
  --tool-description "Evaluates antibody-antigen complexes and target biology: UniProt functional summaries, AlphaFold structural confidence, PDB complexes, CDR binding contacts, and developability liabilities." \
  "$@"

echo
echo "PUBLISH OK — open the Gemini Enterprise app → Agents tab → '${DISPLAY_NAME}'."
echo "Re-running this script updates the existing registration (idempotent)."
