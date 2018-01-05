function Invoke-Vagrant {
    param ( 
        [Parameter(Mandatory=$false,Position=1)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory=$false,Position=2)]
        [string]$Path,
        [Parameter(Mandatory=$false,Position=3)]
        [switch]$Attach
    )

    try
    {  
        
        $Params = @{}

        if ($PSBoundParameters['ArgumentList']) {
            $Params['ArgumentList'] = $PSBoundParameters['ArgumentList']
        }

        $Params['Attach'] = $PSBoundParameters['Attach']

        # Set location to folder if specified.
        if ($Path) {
            Push-Location 
            Set-Location $Path
        }
        
        Write-Verbose "Executing vagrant in location [$(Get-Location)]"

        # Invoke Terraform and process result
        $Result = Invoke-Process -WorkingDirectory (Get-Location | Select-Object -ExpandProperty Path) -PassThru -Path 'vagrant' @Params -Asynchronous

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