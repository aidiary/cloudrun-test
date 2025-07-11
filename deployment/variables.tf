variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "docker_image" {
  description = "Docker image URL in Artifact Registry"
  type        = string
}

variable "allowed_ip" {
  description = "Allowed source IP address for Cloud Armor"
  type        = string
}
