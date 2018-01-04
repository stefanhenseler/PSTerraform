function Set-Terraform {

    Param(
        [Parameter(Mandatory=$false,Position=1)]
        [string]$Path
    )

    $Params = @{}

    if ($PSBoundParameters['Path']) {
        $Params['Path'] = $PSBoundParameters['Path']
    }

    # Execute Terraform config
    Write-Verbose "Creating plan with command 'terraform plan -out=./create.plan'"
    Invoke-Terraform -ArgumentList "plan","-out=`"./create.plan`"" -Path $Path
    Write-Verbose "Applying plan with command 'terraform apply ./create.plan'"
    Invoke-Terraform -ArgumentList "apply","./create.plan" -Path $Path

    Remove-Item -Path (Join-Path $Path "/create.plan") -Force

    # Get config from key vault
    Set-Environment -VaultName (Get-TerraformOutput -Path $Path -OutputName key_vault_name)

}