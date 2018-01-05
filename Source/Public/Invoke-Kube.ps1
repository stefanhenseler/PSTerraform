function Invoke-Kube {
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

        # Invoke kubectl and process result
        $Result = Invoke-Process -PassThru -Path 'kubectl' @Params -CreateNoWindow

        if ($Result.ExitCode -ne 0) {
            throw "StdErr: $($Result.StdErr)`nStdOut: $($Result.StdOut)`nExitCode: $($Result.ExitCode)"
        } 
  
        try {
            # Lets try to convert the json output
            Write-Output (ConvertFrom-Json -InputObject (-join $Result.StdOut))
        } catch {
            "StdErr: $($Result.StdErr) $($_)`nStdOut: $($Result.StdOut)`nExitCode: $($Result.ExitCode)"
    
            # If we cant parse it, just write the output to the pipeline
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