"""
Generates cloudrun/diagram.png — Cloud Run architecture diagram.
Run: python3 cloudrun/gen_diagram.py
Requires: pip install diagrams  &&  apt install graphviz
"""

from diagrams import Diagram, Cluster, Edge
from diagrams.gcp.compute import Run
from diagrams.gcp.network import LoadBalancing, Armor, VPC
from diagrams.gcp.devtools import Build, ContainerRegistry
from diagrams.gcp.security import Iam
from diagrams.onprem.vcs import Github
from diagrams.onprem.client import Users

graph_attr = {
    "fontsize": "13",
    "bgcolor": "white",
    "pad": "1.0",
    "nodesep": "0.8",
    "ranksep": "1.2",
}

node_attr = {
    "fontsize": "11",
}

with Diagram(
    "Cloud Run Architecture",
    filename="cloudrun/diagram",
    outformat="png",
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
):
    users = Users("Users")

    # --- Global Load Balancer + Cloud Armor ---
    with Cluster("Global Load Balancer"):
        armor = Armor("Cloud Armor\nWAF + Rate Limit")
        lb = LoadBalancing("HTTPS LB\nManaged SSL\nHTTP→HTTPS")

    armor >> lb

    # --- Production Cloud Run ---
    with Cluster("Production  (asia-northeast1)"):
        prod = Run("Cloud Run Prod\nLB-only ingress\ncpu_boost / healthz")
        vpc_prod = VPC("VPC Subnet\nDirect VPC Egress")

    # --- Staging Cloud Run ---
    with Cluster("Staging  (asia-northeast1)"):
        staging = Run("Cloud Run Staging\nallAuthenticatedUsers\ncpu_boost / healthz")
        vpc_staging = VPC("VPC Subnet\nDirect VPC Egress")

    # --- CI/CD ---
    with Cluster("CI / CD"):
        github = Github("GitHub")
        build = Build("Cloud Build")
        registry = ContainerRegistry("Artifact Registry\ncleanup: keep 10")
        deploy = Build("Cloud Deploy\nstaging → prod")

    # --- IAM ---
    with Cluster("Service Accounts"):
        sa_run = Iam("SA: run")
        sa_build = Iam("SA: build")
        sa_deploy = Iam("SA: deploy")

    # Traffic flow
    users >> armor
    lb >> Edge(label="Serverless NEG") >> prod
    prod >> Edge(style="dashed") >> vpc_prod
    staging >> Edge(style="dashed") >> vpc_staging

    # CI/CD flow
    github >> build
    build >> registry
    build >> deploy
    deploy >> staging
    deploy >> Edge(label="manual approval") >> prod

    # SA (dashed)
    sa_run >> Edge(style="dashed") >> prod
    sa_run >> Edge(style="dashed") >> staging
    sa_build >> Edge(style="dashed") >> build
    sa_deploy >> Edge(style="dashed") >> deploy
