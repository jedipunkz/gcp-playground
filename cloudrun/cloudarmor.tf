# Cloud Armor security policy attached to the load balancer backend.
# Includes OWASP WAF pre-configured rules and rate limiting.
resource "google_compute_security_policy" "policy" {
  name = "${var.service_name}-armor"

  # --- WAF: OWASP Top 10 pre-configured rules ---
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 1001
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 1002
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-stable')"
      }
    }
    description = "Block Remote Code Execution attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 1003
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }
    description = "Block Local File Inclusion attacks"
  }

  # --- Rate limiting ---
  rule {
    action   = "throttle"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      rate_limit_threshold {
        count        = var.cloud_armor_rate_limit_count
        interval_sec = var.cloud_armor_rate_limit_interval_sec
      }
    }
    description = "Rate limit: ${var.cloud_armor_rate_limit_count} req / ${var.cloud_armor_rate_limit_interval_sec}s per IP"
  }

  # --- Default: allow all other traffic ---
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow"
  }
}
