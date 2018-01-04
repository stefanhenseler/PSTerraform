function Test-AzureServicePrincipal {
    param (
        [Parameter(Mandatory=$true,Position=1)]
        $Name
    )

     # Check if service principal already exists
     $ServicePrincipal = Invoke-Azcli -ArgumentList 'ad','sp','list',"--display-name $Name"

     if ($ServicePrincipal.count -gt 0) {
        Write-Output $true
     } else  {
        Write-Output $false
     }
}