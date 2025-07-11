# cloudrun-test

このリポジトリは、FastAPI アプリケーションを Google Cloud Run にデプロイするためのサンプルプロジェクトです。インフラ構成には Terraform を使用し、Docker でアプリをコンテナ化しています。

---

## 構成概要

- `main.py`  
  FastAPI によるシンプルな Web API（`/`で"Hello, World!"を返す）
- `requirements.txt`  
  FastAPI・Uvicorn などの依存パッケージ
- `Dockerfile`  
  Python 3.12 ベースで FastAPI アプリをコンテナ化
- `deployment/`  
  Terraform による GCP リソース管理（Artifact Registry, Cloud Run など）

---

## デプロイ手順（概要）

1. **Docker イメージのビルドと Artifact Registry への Push**
2. **Terraform で GCP リソース（Artifact Registry, Cloud Run 等）を作成**
3. **Cloud Run へデプロイ**

---

## 主要ファイル

- `main.py`

  ```python
  from fastapi import FastAPI
  from fastapi.responses import PlainTextResponse

  app = FastAPI()

  @app.get("/", response_class=PlainTextResponse)
  def index():
      return "Hello, World!"
  ```

- `Dockerfile`

  ```dockerfile
  FROM python:3.12-slim
  WORKDIR /app
  COPY requirements.txt ./
  RUN pip install --no-cache-dir -r requirements.txt
  COPY . .
  EXPOSE 8080
  CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
  ```

- `deployment/main.tf`
  GCP プロバイダ設定、Artifact Registry・Cloud Run サービスの作成

---

## 必要な環境

- Python 3.12
- Docker
- Terraform
- GCP アカウント

---
