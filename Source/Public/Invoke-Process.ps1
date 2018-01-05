Function Invoke-Process {
    <#
    .SYNOPSIS
        Execute a process with optional arguments, working directory, window style.
    .DESCRIPTION
        Executes a process, e.g. a file included in the Files directory of the App Deploy Toolkit, or a file on the local machine.
        Provides various options for handling the return codes (see Parameters).
    .PARAMETER Path
        Path to the file to be executed. If the file is located directly in the "Files" directory of the App Deploy Toolkit, only the file name needs to be specified.
        Otherwise, the full path of the file must be specified. If the files is in a subdirectory of "Files", use the "$dirFiles" variable as shown in the example.
    .PARAMETER ArgumentList
        Arguments to be passed to the executable
    .PARAMETER SecureParameters
        Hides all parameters passed to the executable from the Toolkit log file
    .PARAMETER WindowStyle
        Style of the window of the process executed. Options: Normal, Hidden, Maximized, Minimized. Default: Normal.
        Note: Not all processes honor the "Hidden" flag. If it it not working, then check the command line options for the process being executed to see it has a silent option.
    .PARAMETER CreateNoWindow
        Specifies whether the process should be started with a new window to contain it. Default is false.
    .PARAMETER WorkingDirectory
        The working directory used for executing the process. Defaults to the directory of the file being executed.
    .PARAMETER NoWait
        Immediately continue after executing the process.
    .PARAMETER PassThru
        Returns ExitCode, STDOut, and STDErr output from the process.
    .PARAMETER Asynchrounus
        Executes the process and grabs the standard output stream asynchrounusly.
    .PARAMETER Attach
        Only valid if Asynchrounus has been specified. This writes the standard output to the console during runtime of the process.
    .PARAMETER WaitForMsiExec
        Sometimes an EXE bootstrapper will launch an MSI install. In such cases, this variable will ensure that
        that this function waits for the msiexec engine to become available before starting the install.
    .PARAMETER MsiExecWaitTime
        Specify the length of time in seconds to wait for the msiexec engine to become available. Default: 600 seconds (10 minutes).
    .PARAMETER IgnoreExitCodes
        List the exit codes to ignore.
    .PARAMETER ContinueOnError
        Continue if an exit code is returned by the process that is not recognized by the App Deploy Toolkit. Default: $false.
    .EXAMPLE
        Invoke-SRProcess -Path 'uninstall_flash_player_64bit.exe' -Parameters '/uninstall' -WindowStyle 'Hidden'
        If the file is in the "Files" directory of the App Deploy Toolkit, only the file name needs to be specified.
    .EXAMPLE
        Invoke-SRProcess -Path "$dirFiles\Bin\setup.exe" -Parameters '/S' -WindowStyle 'Hidden'
    .EXAMPLE
        Invoke-SRProcess -Path 'setup.exe' -Parameters '/S' -IgnoreExitCodes '1,2'
    .EXAMPLE
        Invoke-SRProcess -Path 'setup.exe' -Parameters "-s -f2`"$configToolkitLogDir\$installName.log`""
        Launch InstallShield "setup.exe" from the ".\Files" sub-directory and force log files to the logging folder.
    .EXAMPLE
        Invoke-SRProcess -Path 'setup.exe' -Parameters "/s /v`"ALLUSERS=1 /qn /L* \`"$configToolkitLogDir\$installName.log`"`""
        Launch InstallShield "setup.exe" with embedded MSI and force log files to the logging folder.
    .NOTES
    .LINK
        http://psappdeploytoolkit.com
    #>
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$true)]
            [Alias('FilePath')]
            [ValidateNotNullorEmpty()]
            [string]$Path,
            [Parameter(Mandatory=$false)]
            [Alias('Arguments')]
            [ValidateNotNullorEmpty()]
            [string[]]$ArgumentList,
            [Parameter(Mandatory=$false)]
            [switch]$SecureParameters = $false,
            [Parameter(Mandatory=$false)]
            [ValidateSet('Normal','Hidden','Maximized','Minimized')]
            [Diagnostics.ProcessWindowStyle]$WindowStyle = 'Normal',
            [Parameter(Mandatory=$false)]
            [ValidateNotNullorEmpty()]
            [switch]$CreateNoWindow = $false,
            [Parameter(Mandatory=$false)]
            [ValidateNotNullorEmpty()]
            [switch]$Asynchronous = $false,
            [Parameter(Mandatory=$false)]
            [ValidateNotNullorEmpty()]
            [switch]$Attach = $false,
            [Parameter(Mandatory=$false)]
            [ValidateNotNullorEmpty()]
            [string]$WorkingDirectory,
            [Parameter(Mandatory=$false)]
            [switch]$NoWait = $false,
            [Parameter(Mandatory=$false)]
            [switch]$PassThru = $false,
            [Parameter(Mandatory=$false)]
            [switch]$WaitForMsiExec = $false,
            [Parameter(Mandatory=$false)]
            [ValidateNotNullorEmpty()]
            [timespan]$MsiExecWaitTime = $(New-TimeSpan -Seconds 800),
            [Parameter(Mandatory=$false)]
            [ValidateNotNullorEmpty()]
            [string]$IgnoreExitCodes,
            [Parameter(Mandatory=$false)]
            [ValidateNotNullorEmpty()]
            [boolean]$ContinueOnError = $false
        )
        
        Begin {

        }
        Process {
            Try {
                $private:returnCode = $null
                
                ## Validate and find the fully qualified path for the $Path variable.
                If (([IO.Path]::IsPathRooted($Path)) -and ([IO.Path]::HasExtension($Path))) {
                    Write-Verbose "[$Path] is a valid fully qualified path, continue." 
                    If (-not (Test-Path -LiteralPath $Path -PathType 'Leaf' -ErrorAction 'Stop')) {
                        Throw "File [$Path] not found."
                    }
                }
                Else {
                    #  The first directory to search will be the 'Files' subdirectory of the script directory
                    [string]$PathFolders = $dirFiles
                    #  Add the current location of the console (Windows always searches this location first)
                    [string]$PathFolders = $PathFolders + ';' + (Get-Location -PSProvider 'FileSystem').Path
                    #  Add the new path locations to the PATH environment variable
                    $env:PATH = $PathFolders + ';' + $env:PATH
                    
                    #  Get the fully qualified path for the file. Get-Command searches PATH environment variable to find this value.
                    [string]$FullyQualifiedPath = Get-Command -Name $Path -CommandType 'Application' -TotalCount 1 -Syntax -ErrorAction 'Stop'
                    
                    #  Revert the PATH environment variable to it's original value
                    $env:PATH = $env:PATH -replace [regex]::Escape($PathFolders + ';'), ''
                    
                    If ($FullyQualifiedPath) {
                        Write-Verbose "[$Path] successfully resolved to fully qualified path [$FullyQualifiedPath]." 
                        $Path = $FullyQualifiedPath
                    }
                    Else {
                        Throw "[$Path] contains an invalid path or file name."
                    }
                }
                
                ## Set the Working directory (if not specified)
                If (-not $WorkingDirectory) { $WorkingDirectory = Split-Path -Path $Path -Parent -ErrorAction 'Stop' }
                
                ## If MSI install, check to see if the MSI installer service is available or if another MSI install is already underway.
                ## Please note that a race condition is possible after this check where another process waiting for the MSI installer
                ##  to become available grabs the MSI Installer mutex before we do. Not too concerned about this possible race condition.
                If (($Path -match 'msiexec') -or ($WaitForMsiExec)) {
                    [boolean]$MsiExecAvailable = Test-IsMutexAvailable -MutexName 'Global\_MSIExecute' -MutexWaitTimeInMilliseconds $MsiExecWaitTime.TotalMilliseconds
                    Start-Sleep -Seconds 1
                    If (-not $MsiExecAvailable) {
                        #  Default MSI exit code for install already in progress
                        [int32]$returnCode = 1618
                        Throw 'Please complete in progress MSI installation before proceeding with this install.'
                    }
                }
                
                Try {
                    ## Disable Zone checking to prevent warnings when running executables
                    $env:SEE_MASK_NOZONECHECKS = 1
                    
                    ## Using this variable allows capture of exceptions from .NET methods. Private scope only changes value for current function.
                    $private:previousErrorActionPreference = $ErrorActionPreference
                    $ErrorActionPreference = 'Stop'
                    
                    ## Define process
                    $processStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ErrorAction 'Stop'
                    $processStartInfo.FileName = $Path
                    $processStartInfo.WorkingDirectory = $WorkingDirectory
                    $processStartInfo.UseShellExecute = $false
                    $processStartInfo.ErrorDialog = $false
                    $processStartInfo.RedirectStandardOutput = $true
                    $processStartInfo.RedirectStandardError = $true
                    $processStartInfo.CreateNoWindow = $CreateNoWindow
                    If ($ArgumentList) { $processStartInfo.Arguments = $ArgumentList }
                    If ($windowStyle) { $processStartInfo.WindowStyle = $WindowStyle }
                    $process = New-Object -TypeName 'System.Diagnostics.Process' -ErrorAction 'Stop'
                    $process.StartInfo = $processStartInfo
                    
                    ## Add event handler to capture process's standard output redirection
                    if ($Asynchronous) { 
                        if ($Attach) { 
                            [scriptblock]$processEventHandler = { 
                        
                                Write-Host $Event.SourceEventArgs.Data

                                If (-not [string]::IsNullOrEmpty($EventArgs.Data)) { 
                                    $Event.MessageData.AppendLine($($Event.SourceEventArgs.Data))
                                }
                            }
                        } else {
                            [scriptblock]$processEventHandler = { 
                                If (-not [string]::IsNullOrEmpty($EventArgs.Data)) { 
                                    $Event.MessageData.AppendLine($($Event.SourceEventArgs.Data))
                                }
                            }
                        }

                    # Creating string builders to store stdout and stderr.
                        $stdOutBuilder = New-Object -TypeName System.Text.StringBuilder
                        $stdErrBuilder = New-Object -TypeName System.Text.StringBuilder

                        $StdOutEvent = Register-ObjectEvent -InputObject $process -Action $processEventHandler -EventName 'OutputDataReceived' -MessageData $stdOutBuilder -ErrorAction 'Stop'
                        $StdErrEvent = Register-ObjectEvent -InputObject $process -Action $processEventHandler -EventName 'ErrorDataReceived' -MessageData $stdErrBuilder -ErrorAction 'Stop'
                    }
                    ## Start Process
                    Write-Verbose "Working Directory is [$WorkingDirectory]." 
                    If ($ArgumentList) {
                        If ($ArgumentList -match '-Command \&') {
                            Write-Verbose "Executing [$Path [PowerShell ScriptBlock]]..." 
                        }
                        Else {
                            If ($SecureParameters) {
                                Write-Verbose "Executing [$Path (Parameters Hidden)]..." 
                            }
                            Else {							
                                Write-Verbose "Executing [$Path $ArgumentList]..." 
                            }
                        }
                    }
                    Else {
                        Write-Verbose "Executing [$Path]..." 
                    }
                    [boolean]$processStarted = $process.Start()
                    
                    If ($NoWait) {
                        Write-Verbose 'NoWait parameter specified. Continuing without waiting for exit code...' 
                    }
                    Else {
                        if ($Asynchronous) { 
                            # Start reading the output and error stream
                            $process.BeginOutputReadLine()
                            $process.BeginErrorReadLine()

                            ## HasExited indicates that the associated process has terminated, either normally or abnormally. Wait until HasExited returns $true.
                            While (-not ($process.HasExited)) {
                                $process.Refresh()
                            }

                        } else {

                            # Wait for the process to finish
                            $process.WaitForExit()

                            $stdOut = $process.StandardOutput.ReadToEnd()
                            $stdErr = $process.StandardError.ReadToEnd()
                        }
                        
                        ## Get the exit code for the process
                        Try {
                            [int32]$returnCode = $process.ExitCode
                        }
                        Catch [System.Management.Automation.PSInvalidCastException] {
                            #  Catch exit codes that are out of int32 range
                            [int32]$returnCode = 60013
                        }
                        
                        ## Unregister standard output event to retrieve process output
                        If ($stdOutEvent) { 
                            Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction 'Stop'
                            $stdOutEvent = $null 
                            $stdOut = $stdOutBuilder.ToString() -replace $null,''
                        }

                        If ($stdErrEvent) { 
                            Unregister-Event -SourceIdentifier $stdErrEvent.Name -ErrorAction 'Stop'
                            $stdErrEvent = $null
                            $stdErr = $stdErrBuilder.ToString() -replace $null,''
                        }                        
                        
                        If ($stdErr.Length -gt 0) {
                            Write-Verbose "Standard error output from the process: $stdErr" 
                        }
                    }
                }
                Finally {
                    ## Make sure the standard output event is unregistered
                    If ($stdOutEvent) {
                        Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction 'Stop'
                        $stdOutEvent.Dispose()
                    }
                    If ($stdErrEvent) { 
                        Unregister-Event -SourceIdentifier $stdErrEvent.Name -ErrorAction 'Stop'
                        $stdErrEvent.Dispose()
                    }
                  

                    ## Free resources associated with the process, this does not cause process to exit
                    If ($process) { $process.Close() }

                    if ($null -ne $process){ $process.Dispose() }

                    if ($null -ne $stdEvent)
                    {
                        Unregister-Event -SourceIdentifier $stdEvent.Name
                        $stdEvent.Dispose()
                    }
                    if ($null -ne $errorEvent)
                    {
                        Unregister-Event -SourceIdentifier $errorEvent.Name
                        $errorEvent.Dispose()
                    }
                    
                    ## Re-enable Zone checking
                    Remove-Item -LiteralPath 'env:SEE_MASK_NOZONECHECKS' -ErrorAction 'SilentlyContinue'
                    
                    If ($private:previousErrorActionPreference) { $ErrorActionPreference = $private:previousErrorActionPreference }
                }
                
                If (-not $NoWait) {
                    ## Check to see whether we should ignore exit codes
                    $ignoreExitCodeMatch = $false
                    If ($ignoreExitCodes) {
                        #  Split the processes on a comma
                        [int32[]]$ignoreExitCodesArray = $ignoreExitCodes -split ','
                        ForEach ($ignoreCode in $ignoreExitCodesArray) {
                            If ($returnCode -eq $ignoreCode) { $ignoreExitCodeMatch = $true }
                        }
                    }
                    #  Or always ignore exit codes
                    If ($ContinueOnError) { $ignoreExitCodeMatch = $true }
                    
                    ## If the passthru switch is specified, return the exit code and any output from process
                    If ($PassThru) {
                        Write-Verbose "Execution completed with exit code [$returnCode]." 
                        [psobject]$ExecutionResults = New-Object -TypeName 'PSObject' -Property @{ ExitCode = $returnCode; StdOut = $stdOut; StdErr = $stdErr }
                        Write-Output -InputObject $ExecutionResults
                    }
                    ElseIf ($ignoreExitCodeMatch) {
                        Write-Verbose "Execution complete and the exit code [$returncode] is being ignored." 
                    }
                    ElseIf (($returnCode -eq 3010) -or ($returnCode -eq 1641)) {
                        Write-Verbose "Execution completed successfully with exit code [$returnCode]. A reboot is required."
                        Set-Variable -Name 'msiRebootDetected' -Value $true -Scope 'Script'
                    }
                    ElseIf (($returnCode -eq 1605) -and ($Path -match 'msiexec')) {
                        Write-Verbose "Execution failed with exit code [$returnCode] because the product is not currently installed." 
                    }
                    ElseIf (($returnCode -eq -2145124329) -and ($Path -match 'wusa')) {
                        Write-Verbose "Execution failed with exit code [$returnCode] because the Windows Update is not applicable to this system." 
                    }
                    ElseIf (($returnCode -eq 17025) -and ($Path -match 'fullfile')) {
                        Write-Verbose "Execution failed with exit code [$returnCode] because the Office Update is not applicable to this system." 
                    }
                    ElseIf ($returnCode -eq 0) {
                        Write-Verbose "Execution completed successfully with exit code [$returnCode]." 
                    }
                    Else {
                        [string]$MsiExitCodeMessage = ''
                        If ($Path -match 'msiexec') {
                            [string]$MsiExitCodeMessage = Get-MsiExitCodeMessage -MsiExitCode $returnCode
                        }
                        
                        If ($MsiExitCodeMessage) {
                            Write-Verbose "Execution failed with exit code [$returnCode]: $MsiExitCodeMessage" 
                        }
                        Else {
                            Write-Verbose "Execution failed with exit code [$returnCode]." 
                        }
                        Write-Output $returnCode
                    }
                }
            }
            Catch {
                If ([string]::IsNullOrEmpty([string]$returnCode)) {
                    [int32]$returnCode = 60002
                    Write-Verbose "Function failed, setting exit code to [$returnCode]. `n$(Resolve-Error)" 
                }
                Else {
                    Write-Verbose "Execution completed with exit code [$returnCode]. Function failed. `n$(Resolve-Error)" 
                }
                If ($PassThru) {
                    [psobject]$ExecutionResults = New-Object -TypeName 'PSObject' -Property @{ ExitCode = $returnCode; StdOut = If ($stdOut) { $stdOut } Else { '' }; StdErr = If ($stdErr) { $stdErr } Else { '' } }
                    Write-Output -InputObject $ExecutionResults
                }
                Else {
                    Write-Output $returnCode
                }
            }
        }
        End {
           
        }
    }
