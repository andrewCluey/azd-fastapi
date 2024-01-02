param apimServiceName string
param functionAppName string
param functionApp_rg string
param functionAppId string


/*
DEPENDENCIES
*/

// Consider removing this and having inputs for APIM name and APIM.resource ID
// Having the resource may force the deleyte during AZD down.
// This will need the child resources changign to use name parent/child format rather than `parent` attribute

// LOOKUP Existing APIM
resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimServiceName
}

// Deploy Function App Properties for publishing API to APIM
module functionApp 'functionApp.bicep' = {
  scope: resourceGroup(functionApp_rg)
  name: guid(functionAppName)
  params: {
    apimServiceId: apimService.id
    functionAppName: functionAppName
  }
}


// CREATE APIM services like Backend
resource apimBackend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = {
  parent: apimService
  name: functionAppName
  properties: {
    description: functionAppName
    url: 'https://${functionApp.outputs.functionAppHostname}'
    protocol: 'http'
    resourceId: '${environment().resourceManager}${functionApp.outputs.functionAppId}'
    credentials: {
      header: {
        'x-functions-key': [
          '{{function-app-key}}'
        ]
      }
    }
  }
  dependsOn: [apimNamedValuesKey]
}

// NamedValues
resource apimNamedValuesKey 'Microsoft.ApiManagement/service/namedValues@2023-03-01-preview' = {
  parent: apimService
  name: 'function-app-key'
  properties: {
    displayName: 'function-app-key'
    value: listKeys('${functionAppId}/host/default', '2019-08-01').functionKeys.default
    tags: [
      'key'
      'function'
      'auto'
    ]
    secret: true
  }
}

// Create an API
resource apimAPI 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apimService
  name: 'simple-fastapi-api'
  properties: {
    displayName: 'Protected API Calls'
    apiRevision: '1'
    subscriptionRequired: true
    protocols: [
      'https'
    ]
    path: 'api'
  }
}


// Create an API OPeration - GET
resource apimAPIGet 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: apimAPI
  name: 'generate-name'
  properties: {
    displayName: 'Generate Name'
    method: 'GET'
    urlTemplate: '/generate_name'
  }
}


// CReate an API POlicy for GET Operation
resource apimAPIGetPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  parent: apimAPIGet
  name: 'policy'
  properties: {
    format: 'xml'
    value: '<policies>\r\n<inbound>\r\n<base />\r\n\r\n<set-backend-service id="apim-generated-policy" backend-id="${functionAppName}" />\r\n<rate-limit calls="20" renewal-period="90" remaining-calls-variable-name="remainingCallsPerSubscription" />\r\n<cors allow-credentials="false">\r\n<allowed-origins>\r\n<origin>*</origin>\r\n</allowed-origins>\r\n<allowed-methods>\r\n<method>GET</method>\r\n<method>POST</method>\r\n</allowed-methods>\r\n</cors>\r\n</inbound>\r\n<backend>\r\n<base />\r\n</backend>\r\n<outbound>\r\n<base />\r\n</outbound>\r\n<on-error>\r\n<base />\r\n</on-error>\r\n</policies>'
  }
  dependsOn: [apimBackend]
}

// CReate a new API - PUBLIC-DOCS
resource apimAPIPublic 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apimService
  name: 'public-docs'
  properties: {
    displayName: 'Public Doc Paths'
    apiRevision: '1'
    subscriptionRequired: false
    protocols: [
      'https'
    ]
    path: 'public'
  }
}

// CREATE New API Operation for PUBLIC-DOCS API - GET... /docs
resource apimAPIDocsSwagger 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: apimAPIPublic
  name: 'swagger-docs'
  properties: {
    displayName: 'Documentation'
    method: 'GET'
    urlTemplate: '/docs'
  }
}

// CREATE New API Operation for PUBLIC-DOCS API - GET.. /openapi.json
resource apimAPIDocsSchema 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: apimAPIPublic
  name: 'openapi-schema'
  properties: {
    displayName: 'OpenAPI Schema'
    method: 'GET'
    urlTemplate: '/openapi.json'
  }
}


// API Policy in XML format.. Could be read from a file.
var docsPolicy = '<policies>\r\n<inbound>\r\n<base />\r\n<set-backend-service id="apim-generated-policy" backend-id="${functionAppName}" />\r\n<cache-lookup vary-by-developer="false" vary-by-developer-groups="false" allow-private-response-caching="false" must-revalidate="false" downstream-caching-type="none" />\r\n</inbound>\r\n<backend>\r\n<base />\r\n</backend>\r\n<outbound>\r\n<base />\r\n<cache-store duration="3600" />\r\n</outbound>\r\n<on-error>\r\n<base />\r\n</on-error>\r\n</policies>'

// New API Operation Policy - XML Format.. For PUBLIC-DOCS API - GET... /docs
resource apimAPIDocsSwaggerPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  parent: apimAPIDocsSwagger
  name: 'policy'
  properties: {
    format: 'xml'
    value: docsPolicy
  }
  dependsOn: [apimBackend]
}

resource apimAPIDocsSchemaPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  parent: apimAPIDocsSchema
  name: 'policy'
  properties: {
    format: 'xml'
    value: docsPolicy
  }
  dependsOn: [apimBackend]
}


//output apimServiceUrl string = apimService.properties.gatewayUrl
