terraform {
  required_version = ">= 0.12"
}

variable "project" {
  type        = string
  default     = ""
  description = "Project ID where Terraform is authenticated to run to create additional projects. If provided, Terraform will great the GKE and Tezos cluster inside this project. If not given, Terraform will generate a new project."
}

variable "region" {
  type        = string
  description = "GCP Region. Only necessary when creating cluster manually"
  default = ""
}

variable "billing_account" {
  type        = string
  description = "Billing account ID."
  default = ""
}

variable "kubernetes_namespace" {
  type = string
  description = "kubernetes namespace to deploy the resource into"
  default = "tezos"
}

variable "kubernetes_name_prefix" {
  type = string
  description = "kubernetes name prefix to prepend to all resources (should be short, like DOT)"
  default = "xtz"
}

variable "kubernetes_endpoint" {
  type = string
  description = "name of the kubernetes endpoint"
  default = ""
}

variable "cluster_ca_certificate" {
  type = string
  description = "kubernetes cluster certificate"
  default = ""
}

variable "cluster_name" {
  type = string
  description = "name of the kubernetes cluster"
  default = ""
}

variable "kubernetes_access_token" {
  type = string
  description = "name of the kubernetes endpoint"
  default = ""
}

variable "terraform_service_account_credentials" {
  type = string
  description = "path to terraform service account file, created following the instructions in https://cloud.google.com/community/tutorials/managing-gcp-projects-with-terraform"
  default = "~/.config/gcloud/application_default_credentials.json"
}

variable "kubernetes_pool_name" {

  type = string
  description = "when kubernetes cluster has several node pools, specify which ones to deploy the baking setup into. only effective when deploying on an external cluster with terraform_no_cluster_create"
  default = "blockchain-pool"
}

variable "org_id" {
  type        = string
  description = "Organization ID."
  default = ""
}

variable "full_snapshot_url" {
  type = string
  description = "The public URL where to download the tezos blockchain snapshot for quicker sync of the public nodes"
}

variable "tezos_network" {
  type =string
  description = "The tezos network (alphanet and mainnet supported)"
  default = "mainnet"
}

variable "tezos_version" {
  type =string
  description = "The tezos container version to use. recommended to hard-code it to prevent backwards-incompatible changes to crop up unexpected."
  default = "mainnet"
}


variable "bakers" {
  type = map
  description = "the map of baker data"
}

variable "protocol" {
  type = string
  description = "the tezos protocol currently in use"
  default = "006-PsCARTHA"
}

variable "protocol_short" {
  type = string
  description = "the short string describing the protocol"
  default = "PsCARTHA"
}
