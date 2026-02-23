# Cloud Run Architecture

このディレクトリには、Google Cloud Platform上でCloud Runサービスをデプロイするための完全なTerraform構成が含まれています。

## アーキテクチャ図

**[cloudrun-architecture.drawio](./cloudrun-architecture.drawio)** - Cloud Runディレクトリの構造とGCPアーキテクチャの完全な図

この図には以下が含まれています：
- ディレクトリ構造とTerraformファイルの整理
- GCPリソースとその関係
- CI/CDパイプラインのフロー
- サービスアカウントとIAM権限

### 図の開き方

1. [draw.io](https://app.diagrams.net/)にアクセス
2. "Open Existing Diagram"をクリック
3. `cloudrun-architecture.drawio`ファイルを選択

## ディレクトリ構造

```
cloudrun/
├── provider.tf                  # GCPプロバイダー設定
├── versions.tf                  # Terraformバージョン制約
├── variables.tf                 # 変数定義
├── outputs.tf                   # 出力値
├── terraform.tfvars.example     # 変数の例
├── cloudrun.tf                  # Cloud Runサービス（本番/ステージング）
├── loadbalancer.tf              # グローバルHTTPS Load Balancer
├── cloudarmor.tf                # Cloud Armor WAFとレート制限
├── network.tf                   # VPCネットワークとServerless Connector
├── artifact_registry.tf         # Dockerイメージ用のArtifact Registry
├── iam.tf                       # サービスアカウントとIAM権限
├── cicd.tf                      # Cloud BuildトリガーとCloud Deployパイプライン
├── cloudbuild.yaml              # Cloud Buildビルド設定
├── skaffold.yaml                # Skaffoldデプロイ設定
├── cloudrun-prod.yaml           # 本番環境のCloud Run設定
└── cloudrun-staging.yaml        # ステージング環境のCloud Run設定
```

## 主な機能

- ✅ SSL証明書を使用したHTTPS Load Balancer
- ✅ Cloud Armor WAF保護
- ✅ レート制限（設定可能）
- ✅ Serverless ConnectorによるVPCネットワーク
- ✅ 自動スケーリングCloud Run（最小/最大インスタンス）
- ✅ ステージングと本番環境の分離
- ✅ DockerイメージのためのArtifact Registry
- ✅ Cloud BuildによるCI/CDパイプライン
- ✅ 手動承認機能付きCloud Deploy
- ✅ 最小権限IAMを持つサービスアカウント

## アーキテクチャ概要

### インフラストラクチャ層

1. **Load Balancer**: グローバルHTTPS Load Balancerでカスタムドメインと自動SSL証明書を提供
2. **Cloud Armor**: WAFルール（XSS、SQLi、RCE、LFI保護）とレート制限
3. **Cloud Run**: 本番とステージングのサービス（本番はLB経由、ステージングは直接アクセス）
4. **VPC Network**: VPCリソース（Cloud SQL、Redisなど）への接続用

### CI/CDパイプライン

1. **Cloud Build**: GitHubへのプッシュ時にトリガー
2. **Artifact Registry**: Dockerイメージのビルドとプッシュ
3. **Cloud Deploy**: ステージング → 本番への段階的デプロイ（本番は手動承認が必要）

### サービスアカウント

- **Cloud Run SA**: ランタイム実行用
- **Cloud Build SA**: ビルドとイメージプッシュ用
- **Cloud Deploy SA**: サービスデプロイ用

## デプロイ方法

1. `terraform.tfvars`を作成（`terraform.tfvars.example`を参照）
2. `terraform init`を実行
3. `terraform plan`で変更を確認
4. `terraform apply`でリソースを作成

詳細は各Terraformファイルのコメントを参照してください。
