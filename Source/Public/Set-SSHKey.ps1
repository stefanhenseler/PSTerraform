function Set-SSHKey {
    
    param (
        [Parameter(Mandatory=$true,Position=1)]
        [string]$VariableName,
        [Parameter(Mandatory=$false,Position=2)]
        [string]$SSHKeyPath = '~/.ssh/id_rsa.pub'
    )

    Write-Verbose "Using key from [$SSHKeyPath]"
    if (Test-Path -PathType leaf -Path $SSHKeyPath ) {
        $SSHKey = Get-Content -Path $SSHKeyPath -Raw
        Write-Verbose "Using ssh key [$SSHKey]"
        Set-Item -Path Env:$VariableName -Value $($SSHKey) -Force
    }
}