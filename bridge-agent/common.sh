#!/usr/bin/env bash
# Shared helpers for bridge-agent scripts: loads .env and resolves PROJECT_NUMBER / GE app resource.
HERE_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${HERE_COMMON}/.env" ]]; then
  set -a; # shellcheck disable=SC1091
  source "${HERE_COMMON}/.env"; set +a
else
  echo "Missing ${HERE_COMMON}/.env — copy .env.example and fill it in (or export the variables)."; exit 1
fi

: "${PROJECT_ID:?PROJECT_ID required}"
: "${REGION:=europe-west4}"
: "${GEMINI_MODEL:=gemini-3.8-flash}"
: "${MODEL_LOCATION:=${REGION}}"
: "${STAGING_BUCKET:=gs://${PROJECT_ID}-adk-staging}"
: "${GE_LOCATION:=eu}"
: "${GE_APP_ID:=telix-gemini-enterprise}"
: "${AGENT_PROJECT:=telix-antibody-first-pass}"
: "${DISPLAY_NAME:=Telix Antibody First-Pass}"
: "${DESCRIPTION:=Antibody-antigen complex analysis, target biology, and developability check grounded in DeepMind Science Skills}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing required tool: $1"; exit 1; }; }

if [[ -z "${PROJECT_NUMBER:-}" ]]; then
  PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
fi
export PROJECT_ID REGION MODEL_LOCATION GEMINI_MODEL STAGING_BUCKET GE_LOCATION GE_APP_ID AGENT_PROJECT DISPLAY_NAME DESCRIPTION PROJECT_NUMBER
export GE_APP_RESOURCE="projects/${PROJECT_NUMBER}/locations/${GE_LOCATION}/collections/default_collection/engines/${GE_APP_ID}"
export GOOGLE_CLOUD_PROJECT="${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" >/dev/null 2>&1 || true
