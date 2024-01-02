
param functionAppName string

param apimServiceId string


resource functionApp 'Microsoft.Web/sites@2022-03-01' existing = {
  name: functionAppName
}

resource functionAppProperties 'Microsoft.Web/sites/config@2022-03-01' = {
  parent: functionApp
  name: 'web'
  kind: 'string'
  properties: {
      apiManagementConfig: {
        id: '${apimServiceId}/apis/simple-fastapi-api'
      }
  }
}

output functionAppHostname string = functionApp.properties.hostNames[0]
output functionAppId string = functionApp.id
