function Set-Environment {
    param (
        [Parameter(Mandatory=$true,Position=1)]
        [string]$VaultName
    )

    if (-not (Test-AzureLogin)) {
        throw "Please login to azure 'az login' and select a subscription"
    }

    $Path = (Join-Path $PSScriptRoot .powershell)
    # The vault where he secrets are stored.

    if (-not (Test-Path -Path $Path -Type Container)) {
        New-Item -Path $Path -Force -ItemType Container
    }

    Set-BuildSecrets -KeyVaultName $VaultName -Verbose
    
}