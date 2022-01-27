# Bicep

New-AzResourceGroup -Name demoRG -Location northeurope
New-AzResourceGroupDeployment -ResourceGroupName demoRG -TemplateFile ./webapp.bicep
Enable-AzCdnCustomDomainHttps -ResourceGroupName demoRG -ProfileName profile-12345 -EndpointName endpoint-12345 -CustomDomainName custom-12345
Remove-AzResourceGroup -Name demoRG

## Push to ACR

az acr credential show --resource-group demoRG --name malliinaDemoAcr
docker login malliinaDemoAcr.azurecr.io --username malliinaDemoAcr
docker tag malliina/app:1.0.0 malliinaDemoAcr.azurecr.io/demo:latest
docker push malliinaDemoAcr.azurecr.io/demo:latest

## Database and Passwords

az keyvault create --name DemoVault --resource-group demoRG --location northeurope --enabled-for-template-deployment true
az keyvault secret set --vault-name DemoVault --name "DatabasePassword" --value "secret-password-here"

New-AzResourceGroupDeployment -ResourceGroupName demoRG -TemplateFile ./database.bicep

## Bicep Tutorial

New-AzResourceGroupDeployment -ResourceGroupName demoRG -TemplateFile ./main.bicep -storageName "malliinademostorage"
