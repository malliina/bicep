# Unable to do this in bicep template
Enable-AzCdnCustomDomainHttps -ResourceGroupName $env:ResourceGroupName -ProfileName $env:ProfileName -EndpointName $env:EndpointName -CustomDomainName $env:CustomDomainName
