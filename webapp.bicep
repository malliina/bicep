param location string = resourceGroup().location
param resourceGroupName string = resourceGroup().name
param dockerImageAndTag string = 'demo:latest'
param acrName string = 'malliinaDemoAcr'
param hostname string = 'bicep.malliina.site'
param uniqueId string = uniqueString(resourceGroup().id)

param siteName string = 'site-${uniqueId}'

@description('Name of the CDN Profile')
param profileName string = 'cdn-${uniqueId}'

@description('Name of the CDN Endpoint, must be unique')
param endpointName string = 'endpoint-${uniqueId}'

param customDomainName string = 'custom-domain-${uniqueId}'

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

// Adapted from https://github.com/Azure/bicep/blob/main/docs/examples/301/function-app-with-custom-domain-managed-certificate/main.bicep
// Not used when CDN is used, since CDN manages certificates

// resource siteCustomDomain 'Microsoft.Web/sites/hostNameBindings@2021-02-01' = {
//   name: '${site.name}/${hostname}'
//   properties: {
//     hostNameType: 'Verified'
//     sslState: 'Disabled'
//     customHostNameDnsRecordType: 'CName'
//     siteName: site.name
//   }
// }

// resource certificate 'Microsoft.Web/certificates@2021-02-01' = {
//   name: hostname
//   location: location
//   dependsOn: [
//     siteCustomDomain
//   ]
//   properties: {
//     canonicalName: hostname
//     serverFarmId: appServicePlan.id
//   }
// }

// module siteEnableSni 'sni-enable.bicep' = {
//   name: '${deployment().name}-${siteName}-sni-enable'
//   params: {
//     certificateThumbprint: certificate.properties.thumbprint
//     hostname: hostname
//     siteName: site.name
//   }
// }

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
  name: profileName
  location: location
  sku: {
    name: 'Standard_Microsoft'
  }
}

resource cdnEndpoint 'Microsoft.Cdn/profiles/endpoints@2020-09-01' = {
  parent: cdnProfile
  name: endpointName
  location: location
  properties: {
    originHostHeader: site.properties.defaultHostName
    isHttpAllowed: true
    isHttpsAllowed: true
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
  name: customDomainName
  properties: {
    hostName: hostname
  }
}

// didn't find a way to enable custom https for cdn using arm resources, so a script will have to do
resource cdnEnableCustomHttps 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'cdn-https-${uniqueId}'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    forceUpdateTag: utcValue
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
output publicUrl string = cdnCustomDomain.properties.hostName
output txtDomainVerification string = site.properties.customDomainVerificationId
