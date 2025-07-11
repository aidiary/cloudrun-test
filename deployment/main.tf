provider "google" {
  project = var.project_id
  region  = var.region
}

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.43.0"
    }
  }
}

# Artifact Registry
resource "google_project_service" "artifact_registry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "myrepo" {
  provider = google

  project       = var.project_id
  location      = var.region
  repository_id = "myrepo"
  format        = "DOCKER"

  description = "My Docker repo in Artifact Registry"
}

# Cloud Runのデプロイ
resource "google_cloud_run_service" "myapp" {
  name     = "myapp"
  location = "asia-northeast1"

  template {
    spec {
      containers {
        # 事前にArtifact RegistryにプッシュしたDockerイメージを指定
        image = var.docker_image
      }
    }
  }

  # LBからしかアクセスできなくなる
  # インターネットからエンドポイントにアクセスしても404
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal-and-cloud-load-balancing"
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

# Cloud Runのエンドポイントの認証をオフ
# internal-and-cloud-load-balancingなので安全
resource "google_cloud_run_service_iam_member" "allow_unauthenticated" {
  location = google_cloud_run_service.myapp.location
  service  = google_cloud_run_service.myapp.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Run を接続する NEG
resource "google_compute_region_network_endpoint_group" "neg" {
  name                  = "cloudrun-neg"
  network_endpoint_type = "SERVERLESS"
  region                = "asia-northeast1"

  cloud_run {
    service = google_cloud_run_service.myapp.name
  }
}

# Cloud Run 用バックエンドサービス
resource "google_compute_backend_service" "backend" {
  name        = "cloudrun-backend"
  protocol    = "HTTP"
  port_name   = "http"
  timeout_sec = 30

  backend {
    group = google_compute_region_network_endpoint_group.neg.id
  }

  security_policy = google_compute_security_policy.allow_specific_ip.id
}

# Cloud Load BalancerのServerless NEG がCloud Runを呼び出せるようにする
data "google_project" "project" {
  project_id = var.project_id
}

resource "google_cloud_run_service_iam_member" "neg_invoker" {
  location = google_cloud_run_service.myapp.location
  service  = google_cloud_run_service.myapp.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

# URL マップ（すべてのパスをCloud Runに転送）
resource "google_compute_url_map" "urlmap" {
  name            = "url-map"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "http-proxy"
  url_map = google_compute_url_map.urlmap.id
}

# 自動割り当てのグローバル IP を使う HTTP 転送ルール
resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name                  = "http-forwarding-rule"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
}

# ロードバランサのグローバルIPアドレスを出力
output "load_balancer_ip" {
  value = google_compute_global_forwarding_rule.http_forwarding_rule.ip_address
}

# Cloud Armor セキュリティポリシー
resource "google_compute_security_policy" "allow_specific_ip" {
  name = "allow-only-specific-ip"

  rule {
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = [var.allowed_ip]
      }
    }
    action      = "allow"
    description = "Allow only 126.234.136.211"
  }

  rule {
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    action      = "deny(403)"
    description = "Deny all other IPs"
  }
}
