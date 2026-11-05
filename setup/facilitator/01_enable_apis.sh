#!/usr/bin/env bash
# Enable all Google Cloud APIs required by the workshop.
set -euo pipefail
source "$(dirname "$0")/00_vars.sh"

gcloud config set project "${PROJECT_ID}" >/dev/null

gcloud services enable \
  aiplatform.googleapis.com \
  compute.googleapis.com \
  discoveryengine.googleapis.com \
  agentregistry.googleapis.com \
  storage.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  logging.googleapis.com \
  cloudtrace.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com \
  --project "${PROJECT_ID}"

echo "APIs enabled."
