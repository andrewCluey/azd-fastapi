param name string
param location string = resourceGroup().location
param tags object = {}

param kind string = ''
param reserved bool = true
param sku object // set default and allowed values for ASE
param app_service_environment_id string = ''

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: name
  location: location
  tags: tags
  sku: sku
  kind: kind
  properties: {
    hostingEnvironmentProfile: (app_service_environment_id != '') ? {
      id: app_service_environment_id 
    } : null
    reserved: reserved
  }
}

output id string = appServicePlan.id
