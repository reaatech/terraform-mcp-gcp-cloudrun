terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

locals {
  service_filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.service_name}\" AND resource.labels.location=\"${var.service_location}\""
}

# Cloud Monitoring notification channel (email)
resource "google_monitoring_notification_channel" "email" {
  count        = var.alert_email != null ? 1 : 0
  project      = var.project_id
  display_name = "Alert Channel - ${var.service_name}"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

# Alert policy: High latency (P99). Cloud Run latency metric is in milliseconds.
resource "google_monitoring_alert_policy" "high_latency" {
  project      = var.project_id
  display_name = "High Latency - ${var.service_name}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "P99 Latency > ${var.latency_threshold_ms}ms"
    condition_threshold {
      filter          = "${local.service_filter} AND metric.type=\"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.latency_threshold_ms
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_99"
      }
    }
  }

  notification_channels = try([google_monitoring_notification_channel.email[0].id], [])

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }
}

# Alert policy: High 5xx request rate (errors per second)
resource "google_monitoring_alert_policy" "high_error_rate" {
  project      = var.project_id
  display_name = "High Error Rate - ${var.service_name}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "5xx error rate > ${var.error_rate_rps} req/s"
    condition_threshold {
      filter          = "${local.service_filter} AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.error_rate_rps
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.\"service_name\""]
      }
    }
  }

  notification_channels = try([google_monitoring_notification_channel.email[0].id], [])

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }
}

# Alert policy: High CPU utilization. container/cpu/utilizations is a distribution in [0,1];
# compare to a fraction (e.g. 0.8 = 80%).
resource "google_monitoring_alert_policy" "high_cpu" {
  project      = var.project_id
  display_name = "High CPU - ${var.service_name}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "CPU utilization P99 > ${var.cpu_utilization_threshold}"
    condition_threshold {
      filter          = "${local.service_filter} AND metric.type=\"run.googleapis.com/container/cpu/utilizations\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cpu_utilization_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_PERCENTILE_99"
      }
    }
  }

  notification_channels = try([google_monitoring_notification_channel.email[0].id], [])

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
  }
}

# Cloud Monitoring dashboard
resource "google_monitoring_dashboard" "mcp" {
  project = var.project_id
  dashboard_json = jsonencode({
    displayName = "MCP Server - ${var.service_name}"
    gridLayout = {
      columns = 2
      tiles = [
        {
          title = "Request Rate"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "${local.service_filter} AND metric.type=\"run.googleapis.com/request_count\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.\"service_name\""]
                  }
                }
              }
            }]
            timeshiftDuration = "0s"
            yAxis = {
              label = "Requests/s"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Latency (P99)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "${local.service_filter} AND metric.type=\"run.googleapis.com/request_latencies\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_PERCENTILE_99"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.\"service_name\""]
                  }
                }
              }
            }]
            timeshiftDuration = "0s"
            yAxis = {
              label = "Latency (ms)"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Instance Count"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "${local.service_filter} AND metric.type=\"run.googleapis.com/container/instance_count\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_MEAN"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.\"service_name\""]
                  }
                }
              }
            }]
            timeshiftDuration = "0s"
            yAxis = {
              label = "Instances"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "CPU Utilization (P99)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "${local.service_filter} AND metric.type=\"run.googleapis.com/container/cpu/utilizations\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_PERCENTILE_99"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.\"service_name\""]
                  }
                }
              }
            }]
            timeshiftDuration = "0s"
            yAxis = {
              label = "CPU (0-1)"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "Memory Utilization (P99)"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "${local.service_filter} AND metric.type=\"run.googleapis.com/container/memory/utilizations\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_PERCENTILE_99"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.\"service_name\""]
                  }
                }
              }
            }]
            timeshiftDuration = "0s"
            yAxis = {
              label = "Memory (0-1)"
              scale = "LINEAR"
            }
          }
        },
        {
          title = "5xx Error Rate"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "${local.service_filter} AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
                  aggregation = {
                    perSeriesAligner   = "ALIGN_RATE"
                    crossSeriesReducer = "REDUCE_SUM"
                    groupByFields      = ["resource.label.\"service_name\""]
                  }
                }
              }
            }]
            timeshiftDuration = "0s"
            yAxis = {
              label = "Errors/s"
              scale = "LINEAR"
            }
          }
        }
      ]
    }
  })
}
