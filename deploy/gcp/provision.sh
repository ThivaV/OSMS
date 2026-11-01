#!/usr/bin/env bash
# Creates OSMS's Google Cloud resources, once (DEPLOY.md). Safe to run again: what already
# exists is kept. Needs `gcloud` signed in as the project's owner.
#
#   bash deploy/gcp/provision.sh
#
# - the server: one VM (Ubuntu 24.04, 100 GB disk), a static IP, daily disk snapshots kept
#   for a week; HTTP and HTTPS open, SSH only through Identity-Aware Proxy
# - two service accounts: the server's (reads Secret Manager, nothing else) and the
#   deploy one GitHub Actions uses, keyless (Workload Identity Federation), for the main
#   branch of this repo only
set -euo pipefail
. "$(dirname "$0")/../lib.sh"
load_config
repo=${GITHUB_REPOSITORY:-ThivaV/OSMS}
exists() { "$@" >/dev/null 2>&1; }

echo "== APIs"
g services enable compute.googleapis.com secretmanager.googleapis.com iam.googleapis.com \
  iamcredentials.googleapis.com sts.googleapis.com iap.googleapis.com oslogin.googleapis.com \
  cloudresourcemanager.googleapis.com

echo "== Service accounts"
vm_sa="osms-vm@$GCP_PROJECT_ID.iam.gserviceaccount.com"
deploy_sa="osms-deploy@$GCP_PROJECT_ID.iam.gserviceaccount.com"
exists g iam service-accounts describe "$vm_sa" || g iam service-accounts create osms-vm --display-name "OSMS server"
exists g iam service-accounts describe "$deploy_sa" ||
  g iam service-accounts create osms-deploy --display-name "OSMS deploys from GitHub Actions"
bind() { g projects add-iam-policy-binding "$GCP_PROJECT_ID" --member "serviceAccount:$1" --role "$2" --condition None >/dev/null; }
for role in roles/secretmanager.secretAccessor roles/logging.logWriter roles/monitoring.metricWriter; do bind "$vm_sa" "$role"; done
for role in roles/compute.osAdminLogin roles/compute.viewer roles/iap.tunnelResourceAccessor; do bind "$deploy_sa" "$role"; done
# To SSH into a VM that runs as osms-vm, the deployer must be allowed to act as it.
g iam service-accounts add-iam-policy-binding "$vm_sa" --member "serviceAccount:$deploy_sa" \
  --role roles/iam.serviceAccountUser >/dev/null

echo "== Network"
exists g compute addresses describe osms-ip --region "$GCP_REGION" || g compute addresses create osms-ip --region "$GCP_REGION"
ip=$(g compute addresses describe osms-ip --region "$GCP_REGION" --format 'value(address)')
exists g compute firewall-rules describe osms-web ||
  g compute firewall-rules create osms-web --network default --allow tcp:80,tcp:443 --target-tags osms \
    --description "OSMS: HTTPS, and HTTP for certificates"
exists g compute firewall-rules describe osms-ssh-iap ||
  g compute firewall-rules create osms-ssh-iap --network default --allow tcp:22 --source-ranges 35.235.240.0/20 \
    --target-tags osms --description "OSMS: SSH only through Identity-Aware Proxy"
# This project is OSMS's alone: no SSH or RDP from the whole internet.
for rule in default-allow-ssh default-allow-rdp; do
  if exists g compute firewall-rules describe "$rule"; then g compute firewall-rules delete "$rule"; fi
done

echo "== Server"
if ! exists g compute instances describe "$GCP_VM" --zone "$GCP_ZONE"; then
  g compute instances create "$GCP_VM" --zone "$GCP_ZONE" --machine-type "${GCP_MACHINE_TYPE:-e2-highmem-4}" \
    --image-family ubuntu-2404-lts-amd64 --image-project ubuntu-os-cloud \
    --boot-disk-size 100GB --boot-disk-type pd-balanced \
    --address "$ip" --tags osms --service-account "$vm_sa" --scopes cloud-platform \
    --metadata enable-oslogin=TRUE \
    --shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring
fi
exists g compute resource-policies describe osms-daily --region "$GCP_REGION" ||
  g compute resource-policies create snapshot-schedule osms-daily --region "$GCP_REGION" \
    --daily-schedule --start-time 02:00 --max-retention-days 7 --on-source-disk-delete keep-auto-snapshots
g compute disks add-resource-policies "$GCP_VM" --zone "$GCP_ZONE" --resource-policies osms-daily >/dev/null 2>&1 || true

echo "== GitHub Actions (keyless)"
number=$(g projects describe "$GCP_PROJECT_ID" --format 'value(projectNumber)')
exists g iam workload-identity-pools describe github --location global ||
  g iam workload-identity-pools create github --location global --display-name "GitHub Actions"
exists g iam workload-identity-pools providers describe osms --location global --workload-identity-pool github ||
  g iam workload-identity-pools providers create-oidc osms --location global --workload-identity-pool github \
    --issuer-uri https://token.actions.githubusercontent.com \
    --attribute-mapping "google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
    --attribute-condition "assertion.repository == '$repo' && assertion.ref == 'refs/heads/main'"
g iam service-accounts add-iam-policy-binding "$deploy_sa" --role roles/iam.workloadIdentityUser \
  --member "principalSet://iam.googleapis.com/projects/$number/locations/global/workloadIdentityPools/github/attribute.repository/$repo" \
  >/dev/null

cat <<EOF

Done. The server's address: $ip
- DuckDNS: set ${OSMS_DOMAIN%%.duckdns.org} to $ip (app., auth. and api. follow it).
- GitHub: \`bash deploy/gcp/github.sh\` sets the repo's Actions variables.
EOF
