function Initialize-Terraform {

    Param(
        [Parameter(Mandatory=$false,Position=1)]
        [string]$Path,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$VaultName
    )

    $Params = @{}

    if ($PSBoundParameters['Path']) {
        $Params['Path'] = $PSBoundParameters['Path']
    }

    Set-Environment -VaultName $VaultName

    $Validate = @()
    if (-not $env:TF_VAR_backend_access_key) {$Validate += "[TF_VAR_backend_access_key enviornment] variable is not set"}
    if (-not $env:TF_VAR_backend_resource_group_name) {$Validate += "[TF_VAR_backend_resource_group_name] enviornment variable is not set"}
    if (-not $env:TF_VAR_backend_storage_account_name) {$Validate += "[TF_VAR_backend_storage_account_name] enviornment variable is not set"}
    if (-not $env:TF_VAR_backend_container_name) {$Validate += "[TF_VAR_backend_container_name] enviornment variable is not set"}
    if ($Validate.Count -gt 0) {throw "Coult not initialize terraform, pleas fix the following errors: $Validate "}

    Invoke-Terraform -ArgumentList @(
                                        "init",
                                        "-backend-config=`"access_key=$env:TF_VAR_backend_access_key`"",
                                        "-backend-config=`"resource_group_name=$env:TF_VAR_backend_resource_group_name`"",
                                        "-backend-config=`"storage_account_name=$env:TF_VAR_backend_storage_account_name`"",
                                        "-backend-config=`"container_name=$env:TF_VAR_backend_container_name`""
                                    )`
                     @Params -Attach
}