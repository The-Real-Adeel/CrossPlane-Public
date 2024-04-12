# Fill in the provider subscription ID and Tenant ID
# This is designed to run with Azure CLI: az login needs to occur on the terminal
# Feel free to switch to managed identities/service principal if you feel like
# Ensure your environment has a resource group called "crossplaneRG" which is where we are testing the deployment of crossplane
# It is what we provide RBAC perms to (referencing data source below)
# If you change to a different RG, ensure you also change it in the crossplane resource folder that reference it as well (both)
# NOTE: ACR is not leveraged in this deployment but I have the code in place for my own testing. Feel free to remove it.
# Reference the readme.md for everything else

# Resource Group
resource "azurerm_resource_group" "rg_aks" {
  name     = "RG_AKS"
  location = local.locationCC
}

# Resource Group to create things to
data "azurerm_resource_group" "rg_crossplane" {
  name = "crossplaneRG"
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "corporegistryAKS"
  resource_group_name = azurerm_resource_group.rg_aks.name
  location            = local.locationCC
  sku                 = "Standard"
  admin_enabled       = false
}

# Identity for the cluster
resource "azurerm_user_assigned_identity" "aks-mi" {
  location            = local.locationCC
  name                = "aks-mi"
  resource_group_name = azurerm_resource_group.rg_aks.name
}

# Assignment for this managed identity having owner access
resource "azurerm_role_assignment" "owner" {
  scope                = data.azurerm_resource_group.rg_crossplane.id
  role_definition_name = "owner"
  principal_id         = azurerm_user_assigned_identity.aks-mi.principal_id
}

# Assignment for cluster User Assigned Managed Identity for: it's kubelet identity role assignment
resource "azurerm_role_assignment" "managed_identity_operator" {
  scope                = azurerm_resource_group.rg_aks.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.aks-mi.principal_id
}

# Assignment for cluster User Assigned Managed Identity for: ACR to AKS
resource "azurerm_role_assignment" "acrpull" {
  principal_id                     = azurerm_user_assigned_identity.aks-mi.principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_resource_group.rg_aks.id
  skip_service_principal_aad_check = true
}

# Azure Kubernetes Service Cluster
resource "azurerm_kubernetes_cluster" "aks-cluster" {
  name                = "corpo-aks-crossplane"
  location            = local.locationCC
  resource_group_name = azurerm_resource_group.rg_aks.name
  dns_prefix          = "corpoakscrossplane"

  default_node_pool {
    name                = "default"
    node_count          = 1
    vm_size             = "Standard_B2ms"
    enable_auto_scaling = false
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks-mi.id]
  }
  kubelet_identity { # This identity is used for crossplane creation
    client_id                 = azurerm_user_assigned_identity.aks-mi.client_id
    object_id                 = azurerm_user_assigned_identity.aks-mi.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.aks-mi.id
  }
  depends_on = [azurerm_user_assigned_identity.aks-mi, azurerm_role_assignment.managed_identity_operator]
  tags = {
    name = "test"
  }

}

# Outputs
output "loginServer" {
  value = azurerm_container_registry.acr.login_server
}