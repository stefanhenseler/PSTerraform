function Set-AzureAccountInfo {

    param (
        [Parameter(Mandatory=$true,Position=1)]
        [string]$Prefix
    )

    $Account = Invoke-Azcli -ArgumentList 'account','show'
    Write-Verbose "Account is: [$Account]"
    $ADUser = Invoke-Azcli -ArgumentList 'ad','user','show',"--upn-or-object-id $($Account.user.name)"
    Write-Verbose "User is: [$ADUser]"

    $VarName = "$($Prefix)user_id"
    Write-Verbose "Setting environment variable [$VarName]"
    Set-Item -Path "Env:$VarName" -Value $($ADUser.objectId) -Force

    $VarName = "$($Prefix)azure_subscription_id"
    Write-Verbose "Setting environment variable [$VarName]"
    Set-Item -Path "Env:$VarName" -Value $($Account.id) -Force

    $VarName = "$($Prefix)azure_tenant_id"
    Write-Verbose "Setting environment variable [$VarName]"
    Set-Item -Path "Env:$VarName" -Value $($Account.tenantId) -Force

}