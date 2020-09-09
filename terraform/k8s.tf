# Write the hot wallet private key secret
resource "null_resource" "push_containers" {

  triggers = {
    host = md5(module.terraform-gke-blockchain.kubernetes_endpoint)
    cluster_ca_certificate = md5(
      module.terraform-gke-blockchain.cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    command = <<EOF


find ${path.module}/../docker -mindepth 1 -maxdepth 1 -type d  -printf '%f\n'| while read container; do
  
  pushd ${path.module}/../docker/$container
  cp Dockerfile.template Dockerfile
  sed -i "s/((tezos_version))/${var.tezos_version}/" Dockerfile
  cat << EOY > cloudbuild.yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', "gcr.io/${module.terraform-gke-blockchain.project}/$container:${var.kubernetes_namespace}-latest", '.']
images: ["gcr.io/${module.terraform-gke-blockchain.project}/$container:${var.kubernetes_namespace}-latest"]
EOY
  gcloud builds submit --project ${module.terraform-gke-blockchain.project} --config cloudbuild.yaml .
  rm -v Dockerfile
  rm cloudbuild.yaml
  popd
done
EOF
  }
}

resource "kubernetes_namespace" "tezos_namespace" {
  metadata {
    name = var.kubernetes_namespace
  }
}

# FIXME this is a bug in kustomize where it will not prepend characters to the storageClass requirement
# to address it, we define it here. At some point, later, it will stop being needed.
resource "kubernetes_storage_class" "local-ssd" {
  count = var.kubernetes_name_prefix == "dot" ? 1  : 0
  metadata {
    name = "local-ssd"
  }
  storage_provisioner = "kubernetes.io/gce-pd"
  parameters = {
    type = "pd-ssd"
  }
}

resource "null_resource" "apply" {
  provisioner "local-exec" {

    command = <<EOF
set -e
set -x
gcloud container clusters get-credentials "${module.terraform-gke-blockchain.name}" --region="${module.terraform-gke-blockchain.location}" --project="${module.terraform-gke-blockchain.project}"

mkdir -p ${path.module}/k8s-${var.kubernetes_namespace}
cp -v ${path.module}/../k8s/*yaml* ${path.module}/k8s-${var.kubernetes_namespace}
pushd ${path.module}/k8s-${var.kubernetes_namespace}
cat <<EOK > kustomization.yaml
${templatefile("${path.module}/../k8s/kustomization.yaml.tmpl",
     { "project" : module.terraform-gke-blockchain.project,
       "website_archive": var.website_archive,
       "tezos_version": var.tezos_version,
       "archive_url": var.archive_url,
       "public_baking_key": var.public_baking_key,
       "protocol": var.protocol,
       "protocol_short": var.protocol_short,
       "slack_url": var.slack_url,
       "hot_wallet_public_key": var.hot_wallet_public_key,
       "tezos_network": var.tezos_network,
       "payout_delay": var.payout_delay,
       "payout_fee": var.payout_fee,
       "payout_starting_cycle": var.payout_starting_cycle,
       "witness_payout_address": var.witness_payout_address,
       "website_archive": var.website_archive,
       "website_bucket_url": var.website_bucket_url,
       "kubernetes_namespace": var.kubernetes_namespace,
       "kubernetes_name_prefix": var.kubernetes_name_prefix})}
EOK
kubectl apply -k .
popd
rm -rvf ${path.module}/k8s-${var.kubernetes_namespace}
EOF

  }
  depends_on = [ null_resource.push_containers, kubernetes_namespace.tezos_namespace ]
}
