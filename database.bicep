param resourceGroupId string = resourceGroup().id
param location string = resourceGroup().location
param databaseName string = 'db-${uniqueString(resourceGroupId)}'

@secure()
param databasePassword string

resource mysql 'Microsoft.DBforMySQL/servers@2017-12-01' = {
  name: databaseName
  location: location
  properties: {
    administratorLogin: 'adminUser'
    administratorLoginPassword: databasePassword
    createMode: 'Default'
  }
}
