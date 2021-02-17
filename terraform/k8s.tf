locals {
  kubernetes_variables = { "project" : module.terraform-gke-blockchain.project,
       "tezos_version": var.tezos_version,
       "tezos_network": var.tezos_network,
       "bakers": var.bakers,
       "archive_url": var.archive_url,
       "protocol": var.protocol,
       "protocol_short": var.protocol_short,
       "kubernetes_namespace": var.kubernetes_namespace,
       "kubernetes_name_prefix": var.kubernetes_name_prefix}
}

resource "null_resource" "push_containers" {

  triggers = {
    host = md5(module.terraform-gke-blockchain.kubernetes_endpoint)
    cluster_ca_certificate = md5(
      module.terraform-gke-blockchain.cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    interpreter = [ "/bin/bash", "-c" ]
    command = <<EOF
set -x

build_container () {
  set -x
  cd $1
  container=$(basename $1)
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
}
export -f build_container
find ${path.module}/../docker -mindepth 1 -maxdepth 1 -type d -exec bash -c 'build_container "$0"' {} \; -printf '%f\n'
EOF
  }
}

resource "kubernetes_namespace" "tezos_namespace" {
  metadata {
    name = var.kubernetes_namespace
  }
}

resource "null_resource" "apply" {
  provisioner "local-exec" {

    command = <<EOF
set -e
set -x
gcloud container clusters get-credentials "${module.terraform-gke-blockchain.name}" --region="${module.terraform-gke-blockchain.location}" --project="${module.terraform-gke-blockchain.project}"

rm -rvf ${path.module}/k8s-${var.kubernetes_namespace}
mkdir -p ${path.module}/k8s-${var.kubernetes_namespace}
cp -rv ${path.module}/../k8s/*base* ${path.module}/k8s-${var.kubernetes_namespace}
cd ${abspath(path.module)}/k8s-${var.kubernetes_namespace}
cat <<EOK > kustomization.yaml
${templatefile("${path.module}/../k8s/kustomization.yaml.tmpl", local.kubernetes_variables)}
EOK

mkdir -pv tezos-public-node
cat <<EOK > tezos-public-node/kustomization.yaml
${templatefile("${path.module}/../k8s/tezos-public-node-tmpl/kustomization.yaml.tmpl", local.kubernetes_variables)}
EOK
cat <<EOP > tezos-public-node/nodepool.yaml
${templatefile("${path.module}/../k8s/tezos-public-node-tmpl/nodepool.yaml.tmpl", {"kubernetes_pool_name": var.kubernetes_pool_name})}
EOP
cat <<EOPPVN > tezos-public-node/prefixedpvnode.yaml
${templatefile("${path.module}/../k8s/tezos-public-node-tmpl/prefixedpvnode.yaml.tmpl", {"kubernetes_name_prefix": var.kubernetes_name_prefix})}
EOPPVN
%{ for bakername, baker_data in var.bakers }
mkdir -pv auxiliary-cluster-${bakername}
cat <<EOK > auxiliary-cluster-${bakername}/kustomization.yaml
${templatefile("${path.module}/../k8s/auxiliary-cluster-tmpl/kustomization.yaml.tmpl",
    merge(local.kubernetes_variables,
     { "bakername": bakername,
       "kubernetes_pool_name": var.kubernetes_pool_name,
       "website_archive": baker_data["website_archive"],
       "public_baking_key": baker_data["public_baking_key"],
       "slack_url": baker_data["slack_url"],
       "slack_channel": baker_data["slack_channel"],
       "hot_wallet_public_key": baker_data["hot_wallet_public_key"],
       "hot_wallet_private_key": baker_data["hot_wallet_private_key"],
       "payout_delay": baker_data["payout_delay"],
       "payout_fee": baker_data["payout_fee"],
       "payout_starting_cycle": baker_data["payout_starting_cycle"],
       "witness_payout_address": baker_data["witness_payout_address"],
       "firebase_token": baker_data["firebase_token"],
       "firebase_project": baker_data["firebase_project"]}))}
EOK
cat <<EOP > auxiliary-cluster-${bakername}/crontime.yaml
${templatefile("${path.module}/../k8s/auxiliary-cluster-tmpl/crontime.yaml.tmpl",
     { "payout_cron_schedule": baker_data["payout_cron_schedule"] } ) }
EOP
cat <<EOP > auxiliary-cluster-${bakername}/nodepool.yaml
${templatefile("${path.module}/../k8s/auxiliary-cluster-tmpl/nodepool.yaml.tmpl", {"kubernetes_pool_name": var.kubernetes_pool_name})}
EOP
cat <<EOP > auxiliary-cluster-${bakername}/nodepool-monitor.yaml
${templatefile("${path.module}/../k8s/auxiliary-cluster-tmpl/nodepool-monitor.yaml.tmpl", {"kubernetes_pool_name": var.kubernetes_pool_name})}
EOP
%{ endfor }
kubectl apply -k .
cd ${abspath(path.module)}
rm -rvf ${path.module}/k8s-${var.kubernetes_namespace}
EOF

  }
  depends_on = [ null_resource.push_containers, kubernetes_namespace.tezos_namespace ]
}
