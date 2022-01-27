param resourceGroupId string = resourceGroup().id
param location string = resourceGroup().location
param tenantId string = subscription().tenantId
// todo fix
param objectId string = '7e8068fc-2746-4bff-999c-6e2cee755050'
param vaultName string = 'vault-${uniqueString(resourceGroupId)}'

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: vaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: tenantId
    accessPolicies: [
      {
        objectId: objectId
        permissions: {
          keys: [
            'get'
            'create'
            'delete'
          ]
          secrets: [
            'list'
            'get'
            'set'
            'delete'
          ]
        }
        tenantId: tenantId
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

output vaultName string = keyVault.name
