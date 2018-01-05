function Get-TerraformOutput {

    param (
        [Parameter(Mandatory=$false,Position=1)]
        [string]$Path,
        [Parameter(Mandatory=$false,Position=2)]
        [string]$OutputName
    )

    $Params = @{}

    if ($PSBoundParameters['Path']) {
        $Params['Path'] = $PSBoundParameters['Path']
    }

    # Set terraform arguments
    $Params['ArgumentList'] = @("output")

    if ($PSBoundParameters['OutputName']) {
        $Params['ArgumentList'] += $OutputName
     }
     
    Write-Verbose "Current location is [$(Get-Location)]"
    
    $Output = Invoke-Terraform @Params

    Write-Output $Output.Trim()

}