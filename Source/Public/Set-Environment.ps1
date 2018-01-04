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

    # Get the build secrets module from PSGallery
    Save-Module PSBuildSecrets -Path $Path -Repository PSGallery
    Import-Module (Join-Path $Path PSBuildSecrets)
    Set-BuildSecrets -KeyVaultName $VaultName -Verbose
    
}