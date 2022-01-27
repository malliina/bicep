param vaultName string

param resourceGroupId string = resourceGroup().id
param databaseName string = 'db-${uniqueString(resourceGroupId)}'

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: vaultName
}

module db 'database.bicep' = {
  name: databaseName
  params: {
    databasePassword: kv.getSecret('databasePass')
  }
}
