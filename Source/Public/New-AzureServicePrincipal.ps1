function New-AzureServicePrincipal {
    param (
        [Parameter(Mandatory=$false,Position=1)]
        $Name
    )

    if (-not (Test-AzureLogin)) {
        throw "Please login to azure 'az login' and select a subscription"
    }

    #
    if (Test-AzureServicePrincipal) {

        if (-not $ENV:TF_VAR_azure_client_secret){
            throw "Service Principal [$Name] already exists, please choose another name than [$Name] or set the secret of the existing principal in the environment [set-item -path env:TF_VAR_azure_client_secret -value $Secret]"
        }

        $ServicePrincipal = Invoke-Azcli -ArgumentList 'ad','sp','list',"--display-name $Name"

    } else  {
        $ServicePrincipal = Invoke-Azcli -ArgumentList 'ad','sp','create-for-rbac',"-n $Name"
    }

    Write-Output $ServicePrincipal

}