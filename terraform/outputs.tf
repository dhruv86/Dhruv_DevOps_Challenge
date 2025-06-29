# Outputs
output "app_service_url" {
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
  description = "URL of the deployed application"
}

output "app_service_name" {
  value       = azurerm_linux_web_app.main.name
  description = "Name of the App Service"
}

output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Name of the resource group"
}

output "app_insights_instrumentation_key" {
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
  description = "Application Insights instrumentation key"
}

output "app_service_principal_id" {
  value       = azurerm_linux_web_app.main.identity[0].principal_id
  description = "Principal ID of the App Service managed identity"
}