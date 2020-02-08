# Query the client configuration for our current service account, which shoudl
# have permission to talk to the GKE cluster since it created it.
data "google_client_config" "current" {
}

# This file contains all the interactions with Kubernetes
provider "kubernetes" {
  load_config_file = false
  host             = google_container_cluster.tezos_monitor.endpoint

  cluster_ca_certificate = base64decode(
    google_container_cluster.tezos_monitor.master_auth[0].cluster_ca_certificate,
  )
  token = data.google_client_config.current.access_token
}


# Write the hot wallet private key secret
resource "kubernetes_secret" "hot_wallet_private_key" {
  metadata {
    name = "hot-wallet"
  }

  data = {
    "hot_wallet_private_key" = "${var.hot_wallet_private_key}"
  }
}

resource "kubernetes_secret" "website_builder_key" {
  metadata {
    name = "website-builder-credentials"
  }
  data = {
    json_key = "${base64decode(google_service_account_key.website_builder_key.private_key)}"
  }
}

resource "null_resource" "push_containers" {

  triggers = {
    host = md5(google_container_cluster.tezos_monitor.endpoint)
    client_certificate = md5(
      google_container_cluster.tezos_monitor.master_auth[0].client_certificate,
    )
    client_key = md5(google_container_cluster.tezos_monitor.master_auth[0].client_key)
    cluster_ca_certificate = md5(
      google_container_cluster.tezos_monitor.master_auth[0].cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    command = <<EOF
gcloud auth configure-docker --project "${google_container_cluster.tezos_monitor.project}"

find ${path.module}/../docker -mindepth 1 -type d  -printf '%f\n'| while read container; do
  pushd ${path.module}/../docker/$container
  sed -e "s/((tezos_network))/${var.tezos_network}/" Dockerfile.template > Dockerfile
  tag="gcr.io/${google_container_cluster.tezos_monitor.project}/$container:latest"
  podman build --format docker -t $tag .
  podman push $tag
  rm -v Dockerfile
  popd
done
EOF
  }
}

resource "null_resource" "apply" {
  triggers = {
    host = md5(google_container_cluster.tezos_monitor.endpoint)
    client_certificate = md5(
      google_container_cluster.tezos_monitor.master_auth[0].client_certificate,
    )
    client_key = md5(google_container_cluster.tezos_monitor.master_auth[0].client_key)
    cluster_ca_certificate = md5(
      google_container_cluster.tezos_monitor.master_auth[0].cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    command = <<EOF
gcloud container clusters get-credentials "${google_container_cluster.tezos_monitor.name}" --region="${google_container_cluster.tezos_monitor.region}" --project="${google_container_cluster.tezos_monitor.project}"

cd ${path.module}/../k8s
cat << EOK > kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- tezos-public-node-stateful-set.yaml
- backerei-payout.yaml

imageTags:
  - name: tezos/tezos
    newTag: ${var.tezos_version}
  - name: website-builder
    newName: gcr.io/${google_container_cluster.tezos_monitor.project}/website-builder
    newTag: latest
  - name: tezos-network-monitor
    newName: gcr.io/${google_container_cluster.tezos_monitor.project}/tezos-network-monitor
    newTag: latest
  - name: tezos-archive-downloader
    newName: gcr.io/${google_container_cluster.tezos_monitor.project}/tezos-archive-downloader
    newTag: latest
  - name: tezos-node-with-probes
    newName: gcr.io/${google_container_cluster.tezos_monitor.project}/tezos-node-with-probes
    newTag: latest
  - name: tezos-snapshot-downloader
    newName: gcr.io/${google_container_cluster.tezos_monitor.project}/tezos-snapshot-downloader
    newTag: latest
  - name: payout-cron
    newName: gcr.io/${google_container_cluster.tezos_monitor.project}/payout-cron
    newTag: latest

configMapGenerator:
- name: tezos-configmap
  literals:
  - ARCHIVE_URL="${var.archive_url}"
  - NODE_HOST="localhost"
  - DATA_DIR=/var/run/tezos
  - PUBLIC_BAKING_KEY="${var.public_baking_key}"
  - PROTOCOL="${var.protocol}"
  - PROTOCOL_SHORT="${var.protocol_short}"
- name: tezos-network-monitor-configmap
  literals:
  - NODE_URL="http://localhost:8732"
  - SLACK_URL="${var.slack_url}"
  - SLACK_CHANNEL="general"
  - HOT_WALLET_PUBLIC_KEY="${var.hot_wallet_public_key}" 
  - PUBLIC_BAKING_KEY="${var.public_baking_key}"
- name: backerei-payout-configmap
  literals:
  - HOT_WALLET_PUBLIC_KEY="${var.hot_wallet_public_key}" 
  - SNAPSHOT_INTERVAL="${ var.tezos_network == "mainnet" ? 256 : 128 }"
  - CYCLE_LENGTH="${ var.tezos_network == "mainnet" ? 4096 : 2048 }"
  - PRESERVED_CYCLES="${ var.tezos_network == "mainnet" ? 5 : 3 }"
  - PAYOUT_DELAY="${ var.payout_delay }"
  - PAYOUT_FEE="${ var.payout_fee }"
  - PAYOUT_STARTING_CYCLE="${ var.payout_starting_cycle }"
  - WITNESS_PAYOUT_ADDRESS="${var.witness_payout_address}"
- name: website-builder-configmap
  literals:
  - WEBSITE_ARCHIVE="${var.website_archive}"
  - WEBSITE_BUCKET_URL="${google_storage_bucket.website.url}"
  - PAYOUT_URL="http://payout-json/payouts.json"
  - GOOGLE_APPLICATION_CREDENTIALS="/var/secrets/google/json_key"
EOK
kubectl apply -k .
EOF

  }
}
