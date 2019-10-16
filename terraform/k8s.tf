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
  docker build -t $tag .
  docker push $tag
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
- website-builder.yaml

imageTags:
  - name: tezos/tezos
    newTag: ${var.tezos_network}
  - name: website-builder
    newName: gcr.io/${google_container_cluster.tezos_monitor.project}/website-builder

configMapGenerator:
- name: tezos-configmap
  literals:
  - SNAPSHOT_URL="${var.snapshot_url}"
  - NODE_HOST="localhost"
  - PROTOCOL="004-Pt24m4xi"
  - PROTOCOL_SHORT="Pt24m4xi"
  - DATA_DIR=/var/run/tezos
EOK
cat << EOP > loadbalancerpatch.yaml
apiVersion: v1
kind: Service
metadata:
  name: tezos-remote-signer-forwarding-ingress
spec:
  loadBalancerIP: ${google_compute_address.signer_forwarder_target.address}
EOP
kubectl apply -k .
EOF

  }
  depends_on = [null_resource.push_containers, kubernetes_secret.hot_wallet_private_key]
}
