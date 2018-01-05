function Invoke-Azcli {
    <#
    .SYNOPSIS
        This function is a wrapper for azure cli
    .PARAMETER ArgumentList
        The arguments to be passed on to az
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false,Position=1)]
        [String[]]$ArgumentList,
        [Parameter(Mandatory=$false)]
        [switch]$Attach
    )

    $Params = @{}

    if ($PSBoundParameters['ArgumentList']) {
        $Params['Parameters'] = $PSBoundParameters['ArgumentList']
    }

    $Params['Attach'] = $PSBoundParameters['Attach']
    
    if ($PSBoundParameters['Verbose']){
        $Params['Attach'] = $true
    }

     # Invoke azure cli and process result
     $Result = Invoke-Process -PassThru -Path 'az' @Params -CreateNoWindow

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