param location string = resourceGroup().location
param resourceGroupName string = resourceGroup().name
param dockerImageAndTag string = 'demo:latest'
param hostname string = 'bicep.malliina.site'
param uniqueId string = uniqueString(resourceGroup().id)
param acrName string = 'acr${uniqueId}'
param siteName string = 'site-${uniqueId}'

var websiteName = '${siteName}-site'
var acrRegistry = '${acrName}.azurecr.io'

param utcValue string = utcNow()

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: websiteName
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
}

resource site 'Microsoft.Web/sites@2020-06-01' = {
  name: websiteName
  location: location
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'APPLICATION_SECRET'
          value: containerRegistry.listCredentials().passwords[1].value // TODO use reasonable secret source
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acrRegistry}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acrName
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_CUSTOM_IMAGE_NAME'
          value: '${acrRegistry}/${dockerImageAndTag}'
        }
      ]
      linuxFxVersion: 'DOCKER|${acrRegistry}/${dockerImageAndTag}'
    }
    httpsOnly: true
    serverFarmId: appServicePlan.id
  }
}

resource analyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'demo-workspace'
  location: location
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'demo-diagnostics'
  scope: site
  properties: {
    workspaceId: analyticsWorkspace.id
    logs: [
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
     
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource cdnProfile 'Microsoft.Cdn/profiles@2020-09-01' = {
  name: 'cdn-ms-${uniqueId}'
  location: location
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = {
  parent: cdnProfile
  name: 'endpoint-demo-${uniqueId}'
  location: location
  properties: {
    originHostHeader: site.properties.defaultHostName
    isHttpAllowed: false
    isHttpsAllowed: true
    queryStringCachingBehavior: 'UseQueryString'
    deliveryPolicy: {
      rules: [
        {
          name: 'httpsonly'
          order: 1
          conditions: [
            {
              name: 'RequestScheme'
              parameters: {
                operator: 'Equal'
                matchValues: [
                  'HTTP'
                ]
                '@odata.type': '#Microsoft.Azure.Cdn.Models.DeliveryRuleRequestSchemeConditionParameters'
              }
            }
          ]
          actions: [
            { 
              name: 'UrlRedirect'
              parameters: {
                redirectType: 'TemporaryRedirect'
                destinationProtocol: 'Https'
                '@odata.type': '#Microsoft.Azure.Cdn.Models.DeliveryRuleUrlRedirectActionParameters'
              }
            }
          ]
        }
        {
          name: 'onlyassets'
          order: 2
          conditions: [
            {
              name: 'UrlPath'
              parameters: {
                matchValues: [
                  '/assets/'
                ]
                operator: 'BeginsWith'
                negateCondition: true
                '@odata.type': '#Microsoft.Azure.Cdn.Models.DeliveryRuleUrlPathMatchConditionParameters'
              }
            }
          ]
          actions: [
            {
              name: 'CacheExpiration'
              parameters: {
                cacheBehavior: 'BypassCache'
                cacheType: 'All'
                '@odata.type': '#Microsoft.Azure.Cdn.Models.DeliveryRuleCacheExpirationActionParameters'
              }
            }
          ]
        }
      ]
    }
    origins: [
      {
        name: 'server'
        properties: {
          hostName: site.properties.defaultHostName
        }
      }
    ]
  }
}

resource cdnCustomDomain 'Microsoft.Cdn/profiles/endpoints/customDomains@2020-09-01' = {
  parent: cdnEndpoint
  name: 'custom-domain-${uniqueId}'
  properties: {
    hostName: hostname
  }
}

// https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

// https://github.com/Azure/azure-quickstart-templates/blob/e6e50ae57a2613858b37af1c3e95dfe93733bd4c/quickstarts/microsoft.storage/storage-static-website/main.bicep#L47
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'DeploymentScript'
  location: location
}

// https://github.com/Azure/azure-docs-bicep-samples/blob/main/samples/deployment-script/deploymentscript-keyvault-mi.bicep
resource managedIdentityRole 'Microsoft.Authorization/roleAssignments@2021-04-01-preview' = {
  name: guid(resourceGroup().id, managedIdentity.id, contributorRoleDefinition.id, uniqueId)
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: contributorRoleDefinition.id
    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
}

// didn't find a way to enable custom https for cdn using arm resources, so a script will have to do
resource cdnEnableCustomHttps 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'cdn-https-${uniqueId}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    // forceUpdateTag: utcValue
    azPowerShellVersion: '6.4'
    scriptContent: loadTextContent('./scripts/enable-https.ps1')
    environmentVariables: [
      {
        name: 'ResourceGroupName'
        value: resourceGroupName
      }
      {
        name: 'ProfileName'
        value: cdnProfile.name
      }
      {
        name: 'EndpointName'
        value: cdnEndpoint.name
      }
      {
        name: 'CustomDomainName'
        value: cdnCustomDomain.name
      }
    ]
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    timeout: 'PT1H'
  }
}

output cdnOrigin string = cdnEndpoint.properties.originHostHeader
output cdnEndpoint string = cdnEndpoint.properties.hostName
output publicUrl string = cdnCustomDomain.properties.hostName
output txtDomainVerification string = site.properties.customDomainVerificationId
