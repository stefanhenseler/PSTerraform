function Test-AzureLogin {

    # Get subscription and tenant id
    $Account = Invoke-Azcli -ArgumentList 'account','show'

    if ($Account.state -eq 'Enabled') {
        Write-Output $true
    } else {
        Write-Output $false
    }
}