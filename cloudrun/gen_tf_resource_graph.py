"""
gen_tf_resource_graph.py
Generates:
  cloudrun/tf_resource_graph.drawio  — draw.io XML resource dependency graph
  cloudrun/tf_resource_graph.png     — rendered PNG via graphviz
"""

import subprocess
import xml.etree.ElementTree as ET
from xml.dom import minidom
import os, sys

# ── Resource definitions  id → (display_label, tf_file) ──────────────────────
RESOURCES = {
    # network.tf
    "vpc":         ("google_compute_network\n.vpc",            "network.tf"),
    "subnet":      ("google_compute_subnetwork\n.subnet",      "network.tf"),
    # artifact_registry.tf
    "ar_repo":     ("google_artifact_registry_repository\n.repo", "artifact_registry.tf"),
    # cloudarmor.tf
    "armor":       ("google_compute_security_policy\n.policy", "cloudarmor.tf"),
    # iam.tf – service accounts
    "sa_cr":       ("google_service_account\n.cloudrun",       "iam.tf"),
    "sa_cb":       ("google_service_account\n.cloudbuild",     "iam.tf"),
    "sa_cd":       ("google_service_account\n.clouddeploy",    "iam.tf"),
    # iam.tf – project IAM members (cloudbuild)
    "iam_cb_bld":  ("google_project_iam_member\n.cloudbuild_builder",          "iam.tf"),
    "iam_cb_ar":   ("google_project_iam_member\n.cloudbuild_ar_writer",        "iam.tf"),
    "iam_cb_dep":  ("google_project_iam_member\n.cloudbuild_deploy_releaser",  "iam.tf"),
    "iam_cb_log":  ("google_project_iam_member\n.cloudbuild_log_writer",       "iam.tf"),
    # iam.tf – project IAM members (clouddeploy)
    "iam_cd_run":  ("google_project_iam_member\n.clouddeploy_run_developer",   "iam.tf"),
    "iam_cd_log":  ("google_project_iam_member\n.clouddeploy_log_writer",      "iam.tf"),
    "iam_cd_as":   ("google_service_account_iam_member\n.clouddeploy_act_as_cloudrun", "iam.tf"),
    # iam.tf – cloudrun service invokers
    "iam_cr_prod": ("google_cloud_run_v2_service_iam_member\n.prod_invoker",    "iam.tf"),
    "iam_cr_stg":  ("google_cloud_run_v2_service_iam_member\n.staging_invoker", "iam.tf"),
    # cloudrun.tf
    "cr_prod":     ("google_cloud_run_v2_service\n.app",      "cloudrun.tf"),
    "cr_stg":      ("google_cloud_run_v2_service\n.staging",  "cloudrun.tf"),
    # loadbalancer.tf
    "lb_ip":       ("google_compute_global_address\n.default",                    "loadbalancer.tf"),
    "lb_ssl":      ("google_compute_managed_ssl_certificate\n.default",           "loadbalancer.tf"),
    "lb_neg":      ("google_compute_region_network_endpoint_group\n.cloudrun_neg","loadbalancer.tf"),
    "lb_backend":  ("google_compute_backend_service\n.default",                   "loadbalancer.tf"),
    "lb_urlmap":   ("google_compute_url_map\n.default",                           "loadbalancer.tf"),
    "lb_urlmap_r": ("google_compute_url_map\n.http_redirect",                     "loadbalancer.tf"),
    "lb_proxy_s":  ("google_compute_target_https_proxy\n.default",                "loadbalancer.tf"),
    "lb_proxy_h":  ("google_compute_target_http_proxy\n.http_redirect",           "loadbalancer.tf"),
    "lb_fwd_s":    ("google_compute_global_forwarding_rule\n.https",              "loadbalancer.tf"),
    "lb_fwd_h":    ("google_compute_global_forwarding_rule\n.http",               "loadbalancer.tf"),
    # cicd.tf
    "cd_pipeline": ("google_clouddeploy_delivery_pipeline\n.app",   "cicd.tf"),
    "cd_tgt_stg":  ("google_clouddeploy_target\n.staging",           "cicd.tf"),
    "cd_tgt_prod": ("google_clouddeploy_target\n.prod",              "cicd.tf"),
    "cb_trigger":  ("google_cloudbuild_trigger\n.app",               "cicd.tf"),
}

# ── Dependency edges  (referencing_resource → referenced_resource) ───────────
EDGES = [
    # network
    ("subnet",      "vpc"),
    # cloudrun → dependencies
    ("cr_prod",     "sa_cr"),
    ("cr_prod",     "vpc"),
    ("cr_prod",     "subnet"),
    ("cr_prod",     "ar_repo"),
    ("cr_stg",      "sa_cr"),
    ("cr_stg",      "vpc"),
    ("cr_stg",      "subnet"),
    ("cr_stg",      "ar_repo"),
    # IAM invokers
    ("iam_cr_prod", "cr_prod"),
    ("iam_cr_stg",  "cr_stg"),
    # IAM cloudbuild SA bindings
    ("iam_cb_bld",  "sa_cb"),
    ("iam_cb_ar",   "sa_cb"),
    ("iam_cb_dep",  "sa_cb"),
    ("iam_cb_log",  "sa_cb"),
    # IAM clouddeploy SA bindings
    ("iam_cd_run",  "sa_cd"),
    ("iam_cd_log",  "sa_cd"),
    ("iam_cd_as",   "sa_cr"),
    ("iam_cd_as",   "sa_cd"),
    # Load Balancer HTTPS chain
    ("lb_neg",      "cr_prod"),
    ("lb_backend",  "lb_neg"),
    ("lb_backend",  "armor"),
    ("lb_urlmap",   "lb_backend"),
    ("lb_proxy_s",  "lb_urlmap"),
    ("lb_proxy_s",  "lb_ssl"),
    ("lb_fwd_s",    "lb_proxy_s"),
    ("lb_fwd_s",    "lb_ip"),
    # Load Balancer HTTP redirect chain
    ("lb_proxy_h",  "lb_urlmap_r"),
    ("lb_fwd_h",    "lb_proxy_h"),
    ("lb_fwd_h",    "lb_ip"),
    # CI/CD
    ("cd_tgt_stg",  "sa_cd"),
    ("cd_tgt_prod", "sa_cd"),
    ("cd_pipeline", "cd_tgt_stg"),
    ("cd_pipeline", "cd_tgt_prod"),
    ("cb_trigger",  "sa_cb"),
    ("cb_trigger",  "ar_repo"),
    ("cb_trigger",  "cd_pipeline"),
]

# ── Styling per tf file ───────────────────────────────────────────────────────
FILE_STYLES = {
    "network.tf":           {"fill": "#BBDEFB", "border": "#1565C0", "dot_fill": "#BBDEFB"},
    "artifact_registry.tf": {"fill": "#C8E6C9", "border": "#1B5E20", "dot_fill": "#C8E6C9"},
    "cloudarmor.tf":        {"fill": "#FFCDD2", "border": "#B71C1C", "dot_fill": "#FFCDD2"},
    "iam.tf":               {"fill": "#FFF9C4", "border": "#F57F17", "dot_fill": "#FFF9C4"},
    "cloudrun.tf":          {"fill": "#E8F5E9", "border": "#2E7D32", "dot_fill": "#E8F5E9"},
    "loadbalancer.tf":      {"fill": "#E1BEE7", "border": "#4A148C", "dot_fill": "#E1BEE7"},
    "cicd.tf":              {"fill": "#FCE4EC", "border": "#880E4F", "dot_fill": "#FCE4EC"},
}

# ── Group resources by tf file for DOT subgraphs ─────────────────────────────
FILE_GROUPS = {}
for rid, (label, tf_file) in RESOURCES.items():
    FILE_GROUPS.setdefault(tf_file, []).append(rid)

# ── Build DOT source ──────────────────────────────────────────────────────────
def build_dot():
    lines = [
        'digraph terraform_resources {',
        '  rankdir=LR;',
        '  concentrate=true;',
        '  graph [fontsize=13, fontname="Helvetica", splines=curved, nodesep=0.35, ranksep=1.8];',
        '  node  [shape=box, style="filled,rounded", fontsize=9, fontname="Helvetica", width=3.0, height=0.65, margin="0.15,0.06"];',
        '  edge  [fontsize=7, fontname="Helvetica", arrowsize=0.7, color="#555555"];',
        '',
    ]

    cluster_index = 0
    for tf_file, rids in FILE_GROUPS.items():
        style = FILE_STYLES[tf_file]
        label = tf_file
        lines.append(f'  subgraph cluster_{cluster_index} {{')
        lines.append(f'    label="{label}";')
        lines.append(f'    style="filled,rounded";')
        lines.append(f'    fillcolor="{style["dot_fill"]}55";')  # 33% alpha
        lines.append(f'    color="{style["border"]}";')
        lines.append(f'    fontsize=10;')
        for rid in rids:
            lbl, _ = RESOURCES[rid]
            dot_label = lbl.replace('\n', '\\n')
            lines.append(
                f'    {rid} [label="{dot_label}", fillcolor="{style["dot_fill"]}", color="{style["border"]}"];'
            )
        lines.append('  }')
        lines.append('')
        cluster_index += 1

    for src, dst in EDGES:
        lines.append(f'  {src} -> {dst};')

    lines.append('}')
    return '\n'.join(lines)


# ── Generate PNG ──────────────────────────────────────────────────────────────
def generate_png(dot_source, out_path):
    result = subprocess.run(
        ['dot', '-Tpng', '-Gdpi=180', f'-o{out_path}'],
        input=dot_source, text=True, capture_output=True,
    )
    if result.returncode != 0:
        print("graphviz stderr:", result.stderr, file=sys.stderr)
        sys.exit(1)
    print(f"PNG generated: {out_path}")


# ── Parse graphviz plain output for positions ─────────────────────────────────
def parse_plain(dot_source):
    result = subprocess.run(
        ['dot', '-Tplain'],
        input=dot_source, text=True, capture_output=True,
    )
    positions = {}
    graph_h = 0.0
    scale = 1.0
    for line in result.stdout.splitlines():
        parts = line.split()
        if parts[0] == 'graph':
            scale = float(parts[1])
            graph_h = float(parts[3])
        elif parts[0] == 'node':
            nid = parts[1]
            cx = float(parts[2])
            cy = float(parts[3])
            positions[nid] = (cx, cy, graph_h)
    return positions, scale


# ── Generate draw.io XML ──────────────────────────────────────────────────────
NODE_W  = 230
NODE_H  = 50
DPI     = 72      # graphviz plain uses points (1pt = 1/72 inch)
SCALE_X = 90      # stretch factor for x so clusters don't overlap
SCALE_Y = 72

def generate_drawio(dot_source, out_path):
    positions, _ = parse_plain(dot_source)
    if not positions:
        print("WARNING: could not parse graphviz positions", file=sys.stderr)
        return

    # Flip y (graphviz: origin bottom-left, draw.io: origin top-left)
    all_ys = [cy for _, cy, _ in positions.values()]
    max_y = max(all_ys)

    def to_drawio(cx, cy):
        x = cx * SCALE_X - NODE_W / 2 + 40
        y = (max_y - cy) * SCALE_Y - NODE_H / 2 + 60
        return round(x), round(y)

    # XML skeleton
    mxfile = ET.Element("mxfile", host="app.diagrams.net", version="21.0.0")
    diagram = ET.SubElement(mxfile, "diagram", id="tf-resource-graph",
                            name="Terraform Resource Graph")
    model = ET.SubElement(diagram, "mxGraphModel",
                          dx="1422", dy="762", grid="1", gridSize="10",
                          guides="1", tooltips="1", connect="1", arrows="1",
                          fold="1", page="1", pageScale="1",
                          pageWidth="2000", pageHeight="1400",
                          math="0", shadow="0")
    root = ET.SubElement(model, "root")
    ET.SubElement(root, "mxCell", id="0")
    ET.SubElement(root, "mxCell", id="1", parent="0")

    # Title
    title = ET.SubElement(root, "mxCell",
        id="title", value="Terraform Resource Dependency Graph — cloudrun/",
        style="text;html=1;strokeColor=none;fillColor=none;align=center;"
              "verticalAlign=middle;whiteSpace=wrap;rounded=0;fontSize=16;fontStyle=1;",
        vertex="1", parent="1")
    ET.SubElement(title, "mxGeometry", x="300", y="10", width="1200", height="35",
                  **{"as": "geometry"})

    # Legend
    legend_y = 50
    legend_x = 40
    leg = ET.SubElement(root, "mxCell",
        id="legend_box", value="",
        style="rounded=1;fillColor=#F5F5F5;strokeColor=#9E9E9E;",
        vertex="1", parent="1")
    ET.SubElement(leg, "mxGeometry", x=str(legend_x), y=str(legend_y),
                  width="640", height="30", **{"as": "geometry"})

    legend_items = list(FILE_STYLES.items())
    for i, (tf_file, style) in enumerate(legend_items):
        lx = legend_x + 8 + i * 92
        item = ET.SubElement(root, "mxCell",
            id=f"leg_{i}", value=tf_file,
            style=f"rounded=1;fillColor={style['fill']};strokeColor={style['border']};"
                  f"fontSize=8;fontStyle=1;",
            vertex="1", parent="1")
        ET.SubElement(item, "mxGeometry", x=str(lx), y=str(legend_y + 5),
                      width="84", height="20", **{"as": "geometry"})

    # Nodes
    for rid, (label, tf_file) in RESOURCES.items():
        if rid not in positions:
            continue
        cx, cy, _ = positions[rid]
        dx, dy = to_drawio(cx, cy)
        style = FILE_STYLES[tf_file]
        html_label = label.replace("\n", "<br/>")
        cell = ET.SubElement(root, "mxCell",
            id=rid, value=html_label,
            style=(f"rounded=1;whiteSpace=wrap;html=1;"
                   f"fillColor={style['fill']};strokeColor={style['border']};"
                   f"fontSize=8;fontStyle=1;"),
            vertex="1", parent="1")
        ET.SubElement(cell, "mxGeometry",
                      x=str(dx), y=str(dy),
                      width=str(NODE_W), height=str(NODE_H),
                      **{"as": "geometry"})

    # Edges
    for i, (src, dst) in enumerate(EDGES):
        edge = ET.SubElement(root, "mxCell",
            id=f"edge_{i}", value="",
            style="edgeStyle=orthogonalEdgeStyle;rounded=0;orthogonalLoop=1;"
                  "jettySize=auto;exitX=1;exitY=0.5;exitDx=0;exitDy=0;"
                  "entryX=0;entryY=0.5;entryDx=0;entryDy=0;"
                  "strokeColor=#555555;",
            edge="1", source=src, target=dst, parent="1")
        ET.SubElement(edge, "mxGeometry", relative="1", **{"as": "geometry"})

    # Pretty-print
    raw = ET.tostring(mxfile, encoding="unicode")
    pretty = minidom.parseString(raw).toprettyxml(indent="  ")
    # remove the xml declaration line added by toprettyxml
    lines = pretty.splitlines()
    pretty = "\n".join(lines[1:])

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(pretty)
    print(f"draw.io XML generated: {out_path}")


# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    base = os.path.dirname(os.path.abspath(__file__))
    dot_src = build_dot()

    generate_png(dot_src, os.path.join(base, "tf_resource_graph.png"))
    generate_drawio(dot_src, os.path.join(base, "tf_resource_graph.drawio"))
