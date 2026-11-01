#!/usr/bin/env bash
# Sets the repo's GitHub Actions variables the deploy workflow reads. None is a secret:
# GitHub Actions signs in to Google Cloud without a key (Workload Identity Federation).
#
#   bash deploy/gcp/github.sh
#
# During judging, `gh variable set DEPLOY_ON_PUSH --body false` stops deploys on push;
# the workflow can still be run by hand.
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
load_config
repo=${GITHUB_REPOSITORY:-ThivaV/OSMS}
number=$(g projects describe "$GCP_PROJECT_ID" --format 'value(projectNumber)')

set_var() { gh variable set "$1" --repo "$repo" --body "$2" && echo "set $1"; }
set_var GCP_PROJECT_ID "$GCP_PROJECT_ID"
set_var GCP_REGION "$GCP_REGION"
set_var GCP_ZONE "$GCP_ZONE"
set_var GCP_VM "$GCP_VM"
set_var OSMS_DOMAIN "$OSMS_DOMAIN"
set_var GCP_WIF_PROVIDER "projects/$number/locations/global/workloadIdentityPools/github/providers/osms"
set_var GCP_DEPLOY_SA "osms-deploy@$GCP_PROJECT_ID.iam.gserviceaccount.com"
if [ -z "$(gh variable get DEPLOY_ON_PUSH --repo "$repo" 2>/dev/null || true)" ]; then set_var DEPLOY_ON_PUSH true; fi
