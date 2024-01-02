targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name which is used to generate a short unique hash for each resource')
param name string

@minLength(1)
@description('Primary location for all resources')
param location string

param apim_name string
param apim_resource_group string

/*
***********************
VARIABLES
***********************
*/
var resourceToken = toLower(uniqueString(subscription().id, name, location))
var tags = { 'azd-env-name': name }
var prefix = '${name}-${resourceToken}'
var validStoragePrefix = toLower(take(replace(prefix, '-', ''), 17))


/*
***********************
RESOURCES
***********************
*/

resource resourceGroup 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${name}-func'
  location: location
  tags: tags
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsName: '${prefix}-logworkspace'
    applicationInsightsName: '${prefix}-appinsights'
    applicationInsightsDashboardName: 'appinsights-dashboard'
  }
}

// Backing storage for Azure functions backend API
module storageAccount 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    name: '${validStoragePrefix}storage'
    location: location
    tags: tags
  }
}


// Create an App Service Plan to group applications under the same payment plan and SKU
// Change to create inside app Service Environment
module appServicePlan './core/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    app_service_environment_id: ''
    name: '${prefix}-plan'
    location: location
    tags: tags
    sku: {
      name: 'Y1'
      tier: 'Dynamic'
    }
  }
}

module functionApp 'core/host/functions.bicep' = {
  name: 'function'
  scope: resourceGroup
  params: {
    // Truncating to 32 due to https://github.com/Azure/azure-functions-host/issues/2015
    name: '${take(prefix, 19)}-function-app'
    location: location
    tags: union(tags, { 'azd-service-name': 'api' })
    alwaysOn: false
    appSettings: {
      PYTHON_ISOLATE_WORKER_DEPENDENCIES: 1
      AzureWebJobsFeatureFlags: 'EnableWorkerIndexing'
    }
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanId: appServicePlan.outputs.id
    runtimeName: 'python'
    runtimeVersion: '3.10'
    storageAccountName: storageAccount.outputs.name
  }
}


// Publishes the API in APIM; Creates named_values; Backend; Policies etc in the Azure API Management (APIM) service
module apimAPI 'api.bicep' = {
  scope: az.resourceGroup(apim_resource_group)
  name: 'apimanagement-resources'
  params: {
    functionAppId: functionApp.outputs.id
    functionApp_rg: resourceGroup.name
    apimServiceName: apim_name
    functionAppName: functionApp.outputs.name
  }
  dependsOn: [
    functionApp
  ]
}


/*
***********************
OUTPUTS
***********************
*/
//output SERVICE_API_ENDPOINTS array = ['${apimAPI.outputs.apimServiceUrl}/public/docs']


/*
***********************
USER DEFINED TYPES
***********************
*/
