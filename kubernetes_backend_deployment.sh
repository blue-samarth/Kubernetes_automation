#!/bin/bash

# Kubernetes Deployment Configuration Generator
# Interactive script to generate Terraform configurations for Kubernetes deployments
# Usage: source this file and call deployment_configuration_check()
source "./menu_selector.sh" 2>/dev/null || {
    echo "Error: Could not load menu_selector.sh" >&2
    exit 1
}


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration variables - set via command line parameters
DEPLOYMENT_DIR="${DEPLOYMENT_DIR:-./deployments}"
SERVICE_NAME=""
DEPLOYMENT_STAGE=""
PROVIDER=""
RESOURCE_TYPE=""

# Deployment configuration storage
declare -A DEPLOYMENT_CONFIG

# Function to print colored output
deployment_print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO") echo -e "${BLUE}[DEPLOYMENT-CONFIG-INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[DEPLOYMENT-CONFIG-SUCCESS]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[DEPLOYMENT-CONFIG-WARNING]${NC} $message" ;;
        "ERROR") echo -e "${RED}[DEPLOYMENT-CONFIG-ERROR]${NC} $message" ;;
        "PROMPT") echo -e "${CYAN}[DEPLOYMENT-CONFIG-PROMPT]${NC} $message" ;;
    esac
}

# menu_selector function is imported externally

# Function to parse command line arguments
parse_arguments() {
    if [[ $# -lt 3 ]]; then
        deployment_print_status "ERROR" "Usage: k8s_func <provider> <resource_type> <deployment_stage>"
        deployment_print_status "INFO" "Provider: aws/gcp/azure"
        deployment_print_status "INFO" "Resource Type: backend/frontend/load_test"
        deployment_print_status "INFO" "Deployment Stage: development/production/staging/monitoring"
        deployment_print_status "INFO" "Example: k8s_func gcp backend production"
        return 1
    fi
    
    PROVIDER="$1"
    RESOURCE_TYPE="$2"
    DEPLOYMENT_STAGE="$3"
    
    # Validate provider
    case "$PROVIDER" in
        aws|gcp|azure)
            deployment_print_status "SUCCESS" "Provider: $PROVIDER"
            ;;
        *)
            deployment_print_status "ERROR" "Invalid provider: $PROVIDER. Must be aws/gcp/azure"
            return 1
            ;;
    esac
    
    # Validate resource type
    case "$RESOURCE_TYPE" in
        backend|frontend|load_test)
            deployment_print_status "SUCCESS" "Resource Type: $RESOURCE_TYPE"
            ;;
        *)
            deployment_print_status "ERROR" "Invalid resource type: $RESOURCE_TYPE. Must be backend/frontend/load_test"
            return 1
            ;;
    esac
    
    # Validate deployment stage
    case "$DEPLOYMENT_STAGE" in
        development|production|staging|monitoring)
            deployment_print_status "SUCCESS" "Deployment Stage: $DEPLOYMENT_STAGE"
            ;;
        *)
            deployment_print_status "ERROR" "Invalid deployment stage: $DEPLOYMENT_STAGE. Must be development/production/staging/monitoring"
            return 1
            ;;
    esac
    
    return 0
}

# Function to collect basic service information
deployment_collect_basic_info() {
    deployment_print_status "INFO" "🚀 Welcome to Kubernetes Deployment Configurator"
    deployment_print_status "INFO" "Provider: $PROVIDER | Resource Type: $RESOURCE_TYPE | Stage: $DEPLOYMENT_STAGE"
    echo
    
    # Service name
    while [[ -z "$SERVICE_NAME" ]]; do
        read -p "Enter service name (e.g., user-auth, payment-gateway): " SERVICE_NAME
        if [[ -z "$SERVICE_NAME" ]]; then
            deployment_print_status "ERROR" "Service name cannot be empty"
        elif [[ ! "$SERVICE_NAME" =~ ^[a-z0-9-]+$ ]]; then
            deployment_print_status "ERROR" "Service name must contain only lowercase letters, numbers, and hyphens"
            SERVICE_NAME=""
        fi
    done
    
    DEPLOYMENT_CONFIG["service_name"]="$SERVICE_NAME"
    DEPLOYMENT_CONFIG["deployment_stage"]="$DEPLOYMENT_STAGE"
    DEPLOYMENT_CONFIG["provider"]="$PROVIDER"
    DEPLOYMENT_CONFIG["resource_type"]="$RESOURCE_TYPE"
}

# Function to configure container settings
deployment_configure_container() {
    deployment_print_status "INFO" "📦 Container Configuration"
    echo
    
    # Container port
    menu_selector "Select container port:" port \
        "3000 - Standard Node.js port" \
        "3001 - Alternative Node.js port" \
        "3003 - Backend gateway port" \
        "8080 - Standard web server port" \
        "8000 - Alternative web server port" \
        "9000 - Microservice port" \
        "Custom port" \
        -- "3000" "3001" "3003" "8080" "8000" "9000" "custom"
    
    if [[ "$port" == "custom" ]]; then
        while true; do
            read -p "Enter custom port (1024-65535): " custom_port
            if [[ "$custom_port" =~ ^[0-9]+$ ]] && [[ "$custom_port" -ge 1024 ]] && [[ "$custom_port" -le 65535 ]]; then
                port="$custom_port"
                break
            else
                deployment_print_status "ERROR" "Invalid port. Must be between 1024-65535"
            fi
        done
    fi
    
    DEPLOYMENT_CONFIG["port"]="$port"
    
    # Node environment
    menu_selector "Select Node.js environment:" node_env \
        "Production - Optimized for performance" \
        "Development - Debug mode enabled" \
        "Staging - Production-like with logging" \
        -- "production" "development" "staging"
    
    DEPLOYMENT_CONFIG["node_env"]="$node_env"
    
    # Docker image configuration based on provider and resource type
    read -p "Enter Docker image URL (press Enter for auto-generated): " docker_image
    if [[ -z "$docker_image" ]]; then
        case "$PROVIDER" in
            gcp)
                docker_image="\${local.region}-docker.pkg.dev/\${local.name}/\${module.artifact_registory.project_id}/\${local.org_abbr}-${RESOURCE_TYPE}-${SERVICE_NAME}-service-${DEPLOYMENT_STAGE}:latest"
                ;;
            aws)
                docker_image="\${data.aws_ecr_image.ecr_image_${RESOURCE_TYPE//-/_}_${SERVICE_NAME//-/_}_service_${DEPLOYMENT_STAGE}.image_uri}"
                ;;
            azure)
                docker_image="\${data.azurerm_container_registry.acr_${RESOURCE_TYPE}_${SERVICE_NAME//-/_}_service_${DEPLOYMENT_STAGE}.login_server}/\${local.org_abbr}-${RESOURCE_TYPE}-${SERVICE_NAME}-service-${DEPLOYMENT_STAGE}:latest"
                ;;
        esac
    fi
    DEPLOYMENT_CONFIG["docker_image"]="$docker_image"
}

# Function to configure resource limits and requests
deployment_configure_resources() {
    deployment_print_status "INFO" "💾 Resource Configuration"
    echo
    
    # CPU Limits
    menu_selector "Select CPU limit:" cpu_limit \
        "100m - 1/10th of a CPU core (very light)" \
        "200m - 1/5th of a CPU core (light)" \
        "400m - 2/5th of a CPU core (moderate)" \
        "500m - 1/2 of a CPU core (standard)" \
        "750m - 3/4th of a CPU core (heavy)" \
        "1000m - 1 full CPU core (intensive)" \
        "1500m - 1.5 CPU cores (very intensive)" \
        "2000m - 2 CPU cores (maximum)" \
        -- "100m" "200m" "400m" "500m" "750m" "1000m" "1500m" "2000m"
    
    DEPLOYMENT_CONFIG["cpu_limit"]="$cpu_limit"
    
    # CPU Requests
    menu_selector "Select CPU request (should be less than limit):" cpu_request \
        "50m - 1/20th of a CPU core (minimal)" \
        "100m - 1/10th of a CPU core (light)" \
        "200m - 1/5th of a CPU core (standard)" \
        "300m - 3/10th of a CPU core (moderate)" \
        "400m - 2/5th of a CPU core (heavy)" \
        "500m - 1/2 of a CPU core (intensive)" \
        -- "50m" "100m" "200m" "300m" "400m" "500m"
    
    DEPLOYMENT_CONFIG["cpu_request"]="$cpu_request"
    
    # Memory Limits
    menu_selector "Select memory limit:" memory_limit \
        "128Mi - 128 megabytes (minimal)" \
        "256Mi - 256 megabytes (light)" \
        "512Mi - 512 megabytes (standard)" \
        "768Mi - 768 megabytes (moderate)" \
        "1024Mi - 1 gigabyte (heavy)" \
        "1536Mi - 1.5 gigabytes (intensive)" \
        "2048Mi - 2 gigabytes (very intensive)" \
        "4096Mi - 4 gigabytes (maximum)" \
        -- "128Mi" "256Mi" "512Mi" "768Mi" "1024Mi" "1536Mi" "2048Mi" "4096Mi"
    
    DEPLOYMENT_CONFIG["memory_limit"]="$memory_limit"
    
    # Memory Requests
    menu_selector "Select memory request (should be less than limit):" memory_request \
        "64Mi - 64 megabytes (minimal)" \
        "128Mi - 128 megabytes (light)" \
        "256Mi - 256 megabytes (standard)" \
        "384Mi - 384 megabytes (moderate)" \
        "512Mi - 512 megabytes (heavy)" \
        "768Mi - 768 megabytes (intensive)" \
        -- "64Mi" "128Mi" "256Mi" "384Mi" "512Mi" "768Mi"
    
    DEPLOYMENT_CONFIG["memory_request"]="$memory_request"
    
    # Ephemeral storage
    menu_selector "Select ephemeral storage:" ephemeral_storage \
        "512Mi - 512 megabytes (minimal)" \
        "1Gi - 1 gigabyte (standard)" \
        "2Gi - 2 gigabytes (moderate)" \
        "5Gi - 5 gigabytes (heavy)" \
        -- "512Mi" "1Gi" "2Gi" "5Gi"
    
    DEPLOYMENT_CONFIG["ephemeral_storage"]="$ephemeral_storage"
}

# Function to configure scaling settings
deployment_configure_scaling() {
    deployment_print_status "INFO" "📈 Scaling Configuration"
    echo
    
    # Initial replicas
    menu_selector "Select initial number of replicas:" replicas \
        "1 - Single instance (development)" \
        "2 - High availability minimum" \
        "3 - Standard production setup" \
        "4 - High traffic setup" \
        "5 - Heavy load setup" \
        -- "1" "2" "3" "4" "5"
    
    DEPLOYMENT_CONFIG["replicas"]="$replicas"
    
    # Maximum replicas for HPA
    menu_selector "Select maximum replicas for auto-scaling:" max_replicas \
        "5 - Small scale service" \
        "10 - Medium scale service" \
        "25 - Large scale service" \
        "50 - High scale service" \
        "100 - Enterprise scale service" \
        "200 - Massive scale service" \
        -- "5" "10" "25" "50" "100" "200"
    
    DEPLOYMENT_CONFIG["max_replicas"]="$max_replicas"
    
    # CPU utilization threshold
    menu_selector "Select CPU utilization threshold for scaling:" cpu_threshold \
        "50% - Aggressive scaling (more responsive)" \
        "60% - Standard scaling (balanced)" \
        "70% - Conservative scaling (cost-effective)" \
        "80% - Minimal scaling (resource-efficient)" \
        -- "50" "60" "70" "80"
    
    DEPLOYMENT_CONFIG["cpu_threshold"]="$cpu_threshold"
    
    # Memory utilization threshold
    menu_selector "Select memory utilization threshold for scaling:" memory_threshold \
        "50% - Aggressive scaling (more responsive)" \
        "60% - Standard scaling (balanced)" \
        "70% - Conservative scaling (cost-effective)" \
        "80% - Minimal scaling (resource-efficient)" \
        -- "50" "60" "70" "80"
    
    DEPLOYMENT_CONFIG["memory_threshold"]="$memory_threshold"
}

# Function to configure rolling update strategy
deployment_configure_rolling_update() {
    deployment_print_status "INFO" "🔄 Rolling Update Strategy"
    echo
    
    # Max surge
    menu_selector "Select rolling update max surge:" rolling_update_max_surge \
        "5% - Very conservative (5% of replicas)" \
        "10% - Conservative (10% of replicas)" \
        "25% - Standard (25% of replicas)" \
        "50% - Aggressive (50% of replicas)" \
        "100% - Very aggressive (100% of replicas)" \
        "1 pod - Fixed single pod" \
        "2 pods - Fixed two pods" \
        "3 pods - Fixed three pods" \
        -- "5%" "10%" "25%" "50%" "100%" "1" "2" "3"
    
    DEPLOYMENT_CONFIG["rolling_update_max_surge"]="$rolling_update_max_surge"
    
    # Max unavailable
    menu_selector "Select rolling update max unavailable:" rolling_update_max_unavailable \
        "5% - Very conservative (5% of replicas)" \
        "10% - Conservative (10% of replicas)" \
        "25% - Standard (25% of replicas)" \
        "0 - No unavailable pods (safest)" \
        "1 pod - Fixed single pod" \
        -- "5%" "10%" "25%" "0" "1"
    
    DEPLOYMENT_CONFIG["rolling_update_max_unavailable"]="$rolling_update_max_unavailable"
}

# Function to configure health checks
deployment_configure_health_checks() {
    deployment_print_status "INFO" "🏥 Health Check Configuration"
    echo
    
    # Liveness probe initial delay
    menu_selector "Select liveness probe initial delay:" liveness_initial_delay \
        "5 seconds - Fast startup applications" \
        "10 seconds - Standard applications" \
        "15 seconds - Moderate startup time" \
        "30 seconds - Slow startup applications" \
        "60 seconds - Very slow startup" \
        -- "5" "10" "15" "30" "60"
    
    DEPLOYMENT_CONFIG["liveness_initial_delay"]="$liveness_initial_delay"
    
    # Liveness probe period
    menu_selector "Select liveness probe period:" liveness_period \
        "5 seconds - Frequent checks (high monitoring)" \
        "10 seconds - Standard checks (balanced)" \
        "15 seconds - Moderate checks (resource-efficient)" \
        "30 seconds - Infrequent checks (minimal overhead)" \
        -- "5" "10" "15" "30"
    
    DEPLOYMENT_CONFIG["liveness_period"]="$liveness_period"
    
    # Liveness probe timeout
    menu_selector "Select liveness probe timeout:" liveness_timeout \
        "1 second - Very responsive applications" \
        "2 seconds - Standard applications" \
        "3 seconds - Moderate response time" \
        "5 seconds - Slow applications" \
        -- "1" "2" "3" "5"
    
    DEPLOYMENT_CONFIG["liveness_timeout"]="$liveness_timeout"
    
    # Failure threshold
    menu_selector "Select failure threshold:" failure_threshold \
        "2 failures - Aggressive restart" \
        "3 failures - Standard (balanced)" \
        "5 failures - Conservative restart" \
        "10 failures - Very conservative" \
        -- "2" "3" "5" "10"
    
    DEPLOYMENT_CONFIG["failure_threshold"]="$failure_threshold"
}

# Function to configure scaling behavior
deployment_configure_scaling_behavior() {
    deployment_print_status "INFO" "⚡ Auto-scaling Behavior"
    echo
    
    # Scale down stabilization
    menu_selector "Select scale down stabilization window:" scale_down_stabilization \
        "60 seconds - Aggressive scale down" \
        "120 seconds - Standard scale down" \
        "180 seconds - Conservative scale down" \
        "300 seconds - Very conservative scale down" \
        -- "60" "120" "180" "300"
    
    DEPLOYMENT_CONFIG["scale_down_stabilization"]="$scale_down_stabilization"
    
    # Scale up stabilization
    menu_selector "Select scale up stabilization window:" scale_up_stabilization \
        "60 seconds - Aggressive scale up" \
        "120 seconds - Standard scale up" \
        "180 seconds - Conservative scale up" \
        "300 seconds - Very conservative scale up" \
        -- "60" "120" "180" "300"
    
    DEPLOYMENT_CONFIG["scale_up_stabilization"]="$scale_up_stabilization"
    
    # Scale down policy
    menu_selector "Select scale down policy:" scale_down_policy \
        "Min - Use minimum of all policies" \
        "Max - Use maximum of all policies" \
        "Disabled - Disable scale down" \
        -- "Min" "Max" "Disabled"
    
    DEPLOYMENT_CONFIG["scale_down_policy"]="$scale_down_policy"
    
    # Scale up policy
    menu_selector "Select scale up policy:" scale_up_policy \
        "Min - Use minimum of all policies" \
        "Max - Use maximum of all policies" \
        "Disabled - Disable scale up" \
        -- "Min" "Max" "Disabled"
    
    DEPLOYMENT_CONFIG["scale_up_policy"]="$scale_up_policy"
}

# Function to generate AWS ECR data block
generate_aws_ecr_data_block() {
    local service_name="${DEPLOYMENT_CONFIG["service_name"]}"
    local deployment_stage="${DEPLOYMENT_CONFIG["deployment_stage"]}"
    local resource_type="${DEPLOYMENT_CONFIG["resource_type"]}"
    
    cat << EOF
# AWS ECR Image Data Source
data "aws_ecr_image" "ecr_image_${resource_type}_${service_name//-/_}_service_${deployment_stage}" {
  repository_name = lower(join("-", [local.org_short_name, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
  most_recent     = true
}

EOF
}

generate_azure_container_registry_data_block() {
    local service_name="${DEPLOYMENT_CONFIG["service_name"]}"
    local deployment_stage="${DEPLOYMENT_CONFIG["deployment_stage"]}"
    local resource_type="${DEPLOYMENT_CONFIG["resource_type"]}"

    cat << EOF
# Azure Container Registry Data Source
data "azurerm_container_registry" "acr_${resource_type}_${service_name//-/_}_service_${deployment_stage}" {
  name                = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
  resource_group_name = azurerm_resource_group.rg.name
}
EOF
}

# Function to generate the Terraform configuration
deployment_generate_terraform() {
    local service_name="${DEPLOYMENT_CONFIG["service_name"]}"
    local deployment_stage="${DEPLOYMENT_CONFIG["deployment_stage"]}"
    local provider="${DEPLOYMENT_CONFIG["provider"]}"
    local resource_type="${DEPLOYMENT_CONFIG["resource_type"]}"
    local filename="${provider}_${resource_type}_${service_name}_service_${deployment_stage}.tf"
    
    mkdir -p "$DEPLOYMENT_DIR"
    local filepath="$DEPLOYMENT_DIR/$filename"
    
    cat > "$filepath" << EOF
# Generated Kubernetes Deployment Configuration
# Provider: ${provider}
# Resource Type: ${resource_type}
# Service: ${service_name}
# Stage: ${deployment_stage}
# Generated on: $(date)

$(if [[ "$provider" == "aws" ]]; then generate_aws_ecr_data_block; fi)
$(if [[ "$provider" == "azure" ]]; then generate_azure_container_registry_data_block; fi)

resource "kubernetes_deployment_v1" "deployment_${resource_type}_${service_name//-/_}_service_${deployment_stage}" {
  metadata {
    namespace = kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name
    name      = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
    labels = {
      "app.kubernetes.io/managed-by" = "${provider}-cloud-build-deploy"
      "app.kubernetes.io/name"       = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
      "app.kubernetes.io/component"  = "${resource_type}"
      "app.kubernetes.io/part-of"    = "\${local.org_abbr}-platform"
    }
  }

  spec {
    replicas = ${DEPLOYMENT_CONFIG["replicas"]}

    selector {
      match_labels = {
        app = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
      }
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = "${DEPLOYMENT_CONFIG["rolling_update_max_surge"]}"
        max_unavailable = "${DEPLOYMENT_CONFIG["rolling_update_max_unavailable"]}"
      }
    }

    template {
      metadata {
        labels = {
          app                            = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
          "app.kubernetes.io/managed-by" = "${provider}-cloud-build-deploy"
          "app.kubernetes.io/name"       = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
          "app.kubernetes.io/component"  = "${resource_type}"
          "app.kubernetes.io/part-of"    = "/${local.org_abbr}-platform"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.ksa_${deployment_stage}.metadata[0].name

        container {
          name              = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
          image             = "${DEPLOYMENT_CONFIG["docker_image"]}"
          image_pull_policy = "Always"

          resources {
            limits = {
              cpu                 = "${DEPLOYMENT_CONFIG["cpu_limit"]}"
              memory              = "${DEPLOYMENT_CONFIG["memory_limit"]}"
              "ephemeral-storage" = "${DEPLOYMENT_CONFIG["ephemeral_storage"]}"
            }

            requests = {
              cpu                 = "${DEPLOYMENT_CONFIG["cpu_request"]}"
              memory              = "${DEPLOYMENT_CONFIG["memory_request"]}"
              "ephemeral-storage" = "${DEPLOYMENT_CONFIG["ephemeral_storage"]}"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = ${DEPLOYMENT_CONFIG["port"]}
            }

            initial_delay_seconds = ${DEPLOYMENT_CONFIG["liveness_initial_delay"]}
            period_seconds        = ${DEPLOYMENT_CONFIG["liveness_period"]}
            timeout_seconds       = ${DEPLOYMENT_CONFIG["liveness_timeout"]}
            failure_threshold     = ${DEPLOYMENT_CONFIG["failure_threshold"]}
            success_threshold     = 1
          }

          port {
            name           = "http"
            container_port = ${DEPLOYMENT_CONFIG["port"]}
            protocol       = "TCP"
          }

          dynamic "env" {
            for_each = kubernetes_config_map_v1.config_map_${resource_type}_${service_name//-/_}_service_${deployment_stage}.data
            content {
              name = env.key
              value_from {
                config_map_key_ref {
                  name = kubernetes_config_map_v1.config_map_${resource_type}_${service_name//-/_}_service_${deployment_stage}.metadata[0].name
                  key  = env.key
                }
              }
            }
          }

          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = true
            run_as_non_root            = true

            capabilities {
              add = []
              drop = [
                "NET_RAW",
              ]
            }
          }
        }

        security_context {
          run_as_non_root     = true
          supplemental_groups = []

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        toleration {
          effect   = "NoSchedule"
          key      = "kubernetes.io/arch"
          operator = "Equal"
          value    = "amd64"
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "service_${resource_type}_${service_name//-/_}_service_${deployment_stage}" {
  metadata {
    name      = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
    namespace = kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name
    annotations = ${provider == "gcp" ? {
      "cloud.google.com/neg" = "{\"ingress\": true}"
    } : {} }
  }

  spec {
    selector = {
      app = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
    }

    type = "ClusterIP"

    port {
      name        = "http"
      port        = ${DEPLOYMENT_CONFIG["port"]}
      target_port = ${DEPLOYMENT_CONFIG["port"]}
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "horizontal_pod_autoscaler_${resource_type}_${service_name//-/_}_service_${deployment_stage}" {
  metadata {
    name      = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name]))
    namespace = kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name
  }

  spec {
    scale_target_ref {
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.deployment_${resource_type}_${service_name//-/_}_service_${deployment_stage}.metadata[0].name
      api_version = "apps/v1"
    }

    min_replicas = ${DEPLOYMENT_CONFIG["replicas"]}
    max_replicas = ${DEPLOYMENT_CONFIG["max_replicas"]}

    metric {
      type = "Resource"

      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = ${DEPLOYMENT_CONFIG["cpu_threshold"]}
        }
      }
    }

    metric {
      type = "Resource"

      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = ${DEPLOYMENT_CONFIG["memory_threshold"]}
        }
      }
    }

    behavior {
      scale_down {
        stabilization_window_seconds = ${DEPLOYMENT_CONFIG["scale_down_stabilization"]}
        select_policy                = "${DEPLOYMENT_CONFIG["scale_down_policy"]}"

        policy {
          type           = "Pods"
          value          = 1
          period_seconds = 120
        }

        policy {
          type           = "Percent"
          value          = 50
          period_seconds = 120
        }
      }

      scale_up {
        stabilization_window_seconds = ${DEPLOYMENT_CONFIG["scale_up_stabilization"]}
        select_policy                = "${DEPLOYMENT_CONFIG["scale_up_policy"]}"

        policy {
          type           = "Percent"
          value          = 50
          period_seconds = 60
        }

        policy {
          type           = "Pods"
          value          = 5
          period_seconds = 300
        }
      }
    }
  }
}

resource "kubernetes_config_map_v1" "config_map_${resource_type}_${service_name//-/_}_service_${deployment_stage}" {
  metadata {
    name      = lower(join("-", [local.org_abbr, "${resource_type}", "${service_name}", "service", kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name, "configmap"]))
    namespace = kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name
  }

  data = {
    PORT = ${DEPLOYMENT_CONFIG["port"]}

    NODE_ENV  = "${DEPLOYMENT_CONFIG["node_env"]}"
    NAMESPACE = kubernetes_namespace_v1.namespace_${deployment_stage}.metadata[0].name

    APP_NAME   = "${service_name^} Service"
    APP_PREFIX = ""
    RESOURCE_TYPE = "${resource_type}"
    PROVIDER = "${provider}"
  }
}
EOF

    echo "$filepath"
}

# Function to show configuration summary
deployment_show_summary() {
    deployment_print_status "INFO" "📋 Configuration Summary"
    echo
    echo -e "${CYAN}Service Details:${NC}"
    echo "  Provider: ${DEPLOYMENT_CONFIG["provider"]}"
    echo "  Resource Type: ${DEPLOYMENT_CONFIG["resource_type"]}"
    echo "  Name: ${DEPLOYMENT_CONFIG["service_name"]}"
    echo "  Stage: ${DEPLOYMENT_CONFIG["deployment_stage"]}"
    echo "  Port: ${DEPLOYMENT_CONFIG["port"]}"
    echo "  Environment: ${DEPLOYMENT_CONFIG["node_env"]}"
    echo
    echo -e "${CYAN}Resources:${NC}"
    echo "  CPU: ${DEPLOYMENT_CONFIG["cpu_request"]} request / ${DEPLOYMENT_CONFIG["cpu_limit"]} limit"
    echo "  Memory: ${DEPLOYMENT_CONFIG["memory_request"]} request / ${DEPLOYMENT_CONFIG["memory_limit"]} limit"
    echo "  Storage: ${DEPLOYMENT_CONFIG["ephemeral_storage"]}"
    echo
    echo -e "${CYAN}Scaling:${NC}"
    echo "  Initial Replicas: ${DEPLOYMENT_CONFIG["replicas"]}"
    echo "  Max Replicas: ${DEPLOYMENT_CONFIG["max_replicas"]}"
    echo "  CPU Threshold: ${DEPLOYMENT_CONFIG["cpu_threshold"]}%"
    echo "  Memory Threshold: ${DEPLOYMENT_CONFIG["memory_threshold"]}%"
    echo
    echo -e "${CYAN}Rolling Update:${NC}"
    echo "  Max Surge: ${DEPLOYMENT_CONFIG["rolling_update_max_surge"]}"
    echo "  Max Unavailable: ${DEPLOYMENT_CONFIG["rolling_update_max_unavailable"]}"
    echo
    echo -e "${CYAN}Health Checks:${NC}"
    echo "  Initial Delay: ${DEPLOYMENT_CONFIG["liveness_initial_delay"]}s"
    echo "  Period: ${DEPLOYMENT_CONFIG["liveness_period"]}s"
    echo "  Timeout: ${DEPLOYMENT_CONFIG["liveness_timeout"]}s"
    echo "  Failure Threshold: ${DEPLOYMENT_CONFIG["failure_threshold"]}"
    echo
}

# Main deployment configuration function - k8s_backend_func
k8s_backend_func() {
    # Parse command line arguments
    if ! parse_arguments "$@"; then
        return 1
    fi
    
    deployment_print_status "INFO" "🚀 Starting Kubernetes Deployment Configuration..."
    echo
    
    # Collect all configuration
    deployment_collect_basic_info
    deployment_configure_container
    deployment_configure_resources
    deployment_configure_scaling
    deployment_configure_rolling_update
    deployment_configure_health_checks
    deployment_configure_scaling_behavior
    
    # Show summary
    deployment_show_summary
    
    # Confirm generation
    menu_selector "Generate Terraform configuration?" generate_confirm \
        "Yes - Generate the configuration file" \
        "No - Exit without generating" \
        -- "yes" "no"
    
    if [[ "$generate_confirm" == "yes" ]]; then
        local generated_file
        generated_file=$(deployment_generate_terraform)
        deployment_print_status "SUCCESS" "✅ Configuration generated successfully!"
        deployment_print_status "INFO" "📁 File: $generated_file"
        
        # Option to generate another
        menu_selector "Would you like to generate another deployment?" another_confirm \
            "Yes - Configure another service" \
            "No - Exit" \
            -- "yes" "no"
        
        if [[ "$another_confirm" == "yes" ]]; then
            # Reset configuration
            unset DEPLOYMENT_CONFIG
            declare -A DEPLOYMENT_CONFIG
            SERVICE_NAME=""
            k8s_func "$@"
        fi
    else
        deployment_print_status "INFO" "Configuration cancelled by user"
    fi
}

# Legacy function name for backwards compatibility
deployment_configuration_check() {
    k8s_backend_func "$@"
}

# If script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    k8s_backend_func "$@"
fi