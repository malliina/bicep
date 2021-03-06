# Bicep

To deploy:

```
New-AzResourceGroup -Name demoRG -Location northeurope
New-AzResourceGroupDeployment -ResourceGroupName demoRG -TemplateFile ./webapp.bicep
```

Add a CNAME record to your CDN endpoint address *changeme*.azureedge.net, then try again.

To cleanup:

```
Remove-AzResourceGroup -Name demoRG
```

## Push to ACR

```
Get-AzContainerRegistryCredential -ResourceGroupName demoRG -Name abc
docker login abc.azurecr.io --username abc
docker tag malliina/app:1.1.0 abc.azurecr.io/demo:latest
docker push abc.azurecr.io/demo:latest
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
