#!/usr/bin/env bash
# Shared variables for the facilitator provisioning scripts.
# Copy to 00_vars.local.sh and edit, or export the variables before running.

: "${PROJECT_ID:?Set PROJECT_ID, e.g. export PROJECT_ID=telix-agent-workshop}"
export PROJECT_ID
export REGION="${REGION:-europe-west4}"            # Agent Runtime region (EU)
export MODEL_LOCATION="${MODEL_LOCATION:-eu}"      # Gemini inference: EU jurisdictional endpoint (data-resident)
export GE_LOCATION="${GE_LOCATION:-eu}"            # Gemini Enterprise multi-region
export GE_APP_ID="${GE_APP_ID:-telix-gemini-enterprise}"  # Gemini Enterprise app id (created in console)
export GEMINI_MODEL="${GEMINI_MODEL:-gemini-3.8-flash}"
export STAGING_BUCKET="${STAGING_BUCKET:-gs://${PROJECT_ID}-adk-staging}"
export WORKSHOP_BUCKET="${WORKSHOP_BUCKET:-gs://${PROJECT_ID}-workshop}"

PROJECT_NUMBER="$(gcloud projects describe "${PROJECT_ID}" --format='value(projectNumber)')"
export PROJECT_NUMBER
export GE_APP_RESOURCE="projects/${PROJECT_NUMBER}/locations/${GE_LOCATION}/collections/default_collection/engines/${GE_APP_ID}"

echo "Project:        ${PROJECT_ID} (${PROJECT_NUMBER})"
echo "Region:         ${REGION}"
echo "GE app:         ${GE_APP_RESOURCE}"
echo "Model:          ${GEMINI_MODEL} @ ${MODEL_LOCATION}"
echo "Staging bucket: ${STAGING_BUCKET}"
echo "Workshop bucket:${WORKSHOP_BUCKET}"
