# Bicep

```
New-AzResourceGroup -Name demoRG -Location northeurope
New-AzResourceGroupDeployment -ResourceGroupName demoRG -TemplateFile ./webapp.bicep
Remove-AzResourceGroup -Name demoRG
```

## Push to ACR

```
Get-AzContainerRegistryCredential -ResourceGroupName demoRG -Name malliinaDemoAcr
docker login malliinaDemoAcr.azurecr.io --username malliinaDemoAcr
docker tag malliina/app:1.0.0 malliinaDemoAcr.azurecr.io/demo:latest
docker push malliinaDemoAcr.azurecr.io/demo:latest
```

## Database and Passwords

```
New-AzResourceGroupDeployment -ResourceGroupName demoRG -TemplateFile ./vault.bicep
$Secret = ConvertTo-SecureString -String 'secret-password-here' -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName 'vault-name-here' -Name 'databasePass' -SecretValue $Secret
New-AzResourceGroupDeployment -ResourceGroupName demoRG -TemplateFile ./database-vault.bicep
```

## Bicep Tutorial

```
New-AzResourceGroupDeployment -ResourceGroupName demoRG -TemplateFile ./main.bicep -storageName "malliinademostorage"
```
