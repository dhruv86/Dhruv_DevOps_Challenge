# Generate unique suffix for globally unique names
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Local variables
locals {
  app_name = "${var.app_name_prefix}-${random_string.suffix.result}"
  tags = {
    Environment = var.environment
    Project     = "HelloWorld"
    ManagedBy   = "Terraform"
    CreatedBy   = "dhruv86"
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# App Service Plan - Standard Tier with Linux
resource "azurerm_service_plan" "main" {
  name                = "asp-${local.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = "S1" # Standard tier
  
  tags = local.tags
}

# Application Insights
resource "azurerm_application_insights" "main" {
  name                = "ai-${local.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
  
  tags = local.tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  
  tags = local.tags
}

# Linux Web App
resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.app_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  
  https_only = true # Enforce HTTPS
  
  site_config {
    always_on        = true
    linux_fx_version = "STATICSITE|1.0"
    
    # Security headers
    http2_enabled                     = true
    minimum_tls_version              = "1.2"
    ftps_state                       = "Disabled"
    vnet_route_all_enabled           = false
    
    # IP Restrictions - Allow all for demo, customize as needed
    ip_restriction {
      action      = "Allow"
      name        = "AllowAll"
      priority    = 100
      ip_address  = "0.0.0.0/0"
    }
    
    # Health check
    health_check_path = "/"
    
    application_stack {
      node_version = "18-lts"
    }
  }
  
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.main.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string
    "WEBSITE_RUN_FROM_PACKAGE"             = "1"
  }
  
  # Enable logging
  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
    
    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
    
    application_logs {
      file_system_level = "Information"
    }
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  tags = local.tags
}

# Auto-scaling settings
resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "as-${local.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_service_plan.main.id
  
  profile {
    name = "default"
    
    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }
    
    # Scale up rule - CPU > 70%
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    
    # Scale down rule - CPU < 30%
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }
      
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    
    # Scale up rule - Memory > 80%
    rule {
      metric_trigger {
        metric_name        = "MemoryPercentage"
        metric_resource_id = azurerm_service_plan.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 80
      }
      
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
  
  notification {
    email {
      send_to_subscription_administrator    = true
      # send_to_subscription_co_administrators = true
    }
  }
  
  tags = local.tags
}

# Metric Alerts
resource "azurerm_monitor_metric_alert" "high_cpu" {
  name                = "alert-high-cpu-${local.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_service_plan.main.id]
  description         = "Alert when CPU usage is high"
  
  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "CpuPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  window_size        = "PT5M"
  frequency          = "PT1M"
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  tags = local.tags
}

resource "azurerm_monitor_metric_alert" "high_memory" {
  name                = "alert-high-memory-${local.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_service_plan.main.id]
  description         = "Alert when memory usage is high"
  
  criteria {
    metric_namespace = "Microsoft.Web/serverfarms"
    metric_name      = "MemoryPercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }
  
  window_size        = "PT5M"
  frequency          = "PT1M"
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  tags = local.tags
}

resource "azurerm_monitor_metric_alert" "http_errors" {
  name                = "alert-http-errors-${local.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_web_app.main.id]
  description         = "Alert when HTTP 5xx errors occur"
  
  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }
  
  window_size        = "PT5M"
  frequency          = "PT1M"
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
  
  tags = local.tags
}

# Action Group for Alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${local.app_name}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "HelloAlert"
  
  email_receiver {
    name                    = "sendtoadmin"
    email_address          = "admin@example.com" # Change this
    use_common_alert_schema = true
  }
  
  tags = local.tags
}

# Diagnostic Settings
resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-${local.app_name}"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  enabled_log {
    category = "AppServiceHTTPLogs"
    #enabled  = true
  }
  
  enabled_log {
    category = "AppServiceConsoleLogs"
    #enabled  = true
  }
  
  enabled_log {
    category = "AppServiceAppLogs"
    #enabled  = true
  }
  
  enabled_log {
    category = "AppServiceAuditLogs"
    #enabled  = true
  }
  
  # metric {
  #   category = "AllMetrics"
  #   enabled  = true
  # }
}

