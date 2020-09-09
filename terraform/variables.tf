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

variable "org_id" {
  type        = string
  description = "Organization ID."
  default = ""
}

variable "archive_url" {
  type = string
  description = "The public URL where to download the tezos blockchain archive for quicker sync"
}

variable "snapshot_url" {
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


variable "website" {
  type = string
  description = "address of the baker's static website hosted on gcp"
}

variable "website_archive" {
  type = string
  description = "URL of the archive for the jekyll website to deploy"
}

variable "website_bucket_url" {
  type = string
  description = "URL of the Google Storage Bucket for the website"
}

variable "slack_url" {
  type = string
  description = "Slack auth url to post alerts"
}

variable "public_baking_key" {
  type  = string
  description = "The public baker tz1 public key that delegators delegate to"
}

variable "hot_wallet_public_key" {
  type = string
  description = "The public key of the hot wallet or payout wallet (where rewards come from)"
}

variable "payout_delay" {
  type =string
  description = "Number of cycles to delay the payout compared to PRESERVED_CYCLES (can be negatives to pay out in advance)"
}

variable "payout_fee" {
  type = string
  description = "the fee, formatted in 'numerator % denominator', for example '11 % 100' for a 11% fee"
  default = "10 % 100"
}

variable "payout_starting_cycle" {
  type = string
  description = "the number of first cycle for which you want to send payouts. for safety, so you don't send older payments again"
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

variable "witness_payout_address" {
  type = string
  description = "A test delegate that you set up and permanently delegates to the baking address. Used for secondary verifications that payouts have not been done yet, to avoid double payouts. Do not set it to the payout address. Have a test delegation to yourself."
}
