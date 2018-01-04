function Invoke-Terraform {
    param ( 
        [Parameter(Mandatory=$false,Position=1)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory=$false,Position=2)]
        [string]$Path,
        [Parameter(Mandatory=$false,Position=3)]
        [switch]$NoConsoleOutput
    )

    try
    {  
        
        $Params = @{}

        if ($PSBoundParameters['ArgumentList']) {
            $Params['Parameters'] = $PSBoundParameters['ArgumentList']
        }

        if($PSBoundParameters['NoConsoleOutput']){
            $Params['Attach'] = $false
        } else {
            $Params['Attach'] = $true
        }

        # Set location to folder if specified.
        if ($Path) {
            Push-Location 
            Set-Location $Path
        }
        
        Write-Verbose "Executing Terraform in location [$(Get-Location)]"

        # Invoke Terraform and process result
        $Result = Invoke-Process -WorkingDirectory (get-location | Select-Object -ExpandProperty Path) -PassThru -Path 'terraform' @Params -Asynchronous

        if ($Result.ExitCode -ne 0) {
            throw "StdErr: $($Result.StdErr)`nStdOut: $($Result.StdOut)`nExitCode: $($Result.ExitCode)"
        } else {
            Write-Output $Result.StdOut
        }

    }
    catch {
        Write-Verbose (Resolve-Error)
        Write-Error "$($Result.StdErr)`n" -TargetObject $Result
    }
    finally
    {
        if ($Path) {
            Pop-Location
        }
    }
}