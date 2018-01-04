 function Set-SRVariablesFromJson {
    <#
    .SYNOPSIS
        Reads a json file and sets environment variables.
    .DESCRIPTION
        Reads a Json file and sets all key value pairs in the root element of the file as environment variables
    .PARAMETER Path 
        The Path to the JSON file to be parsed.
    .PARAMETER Prefix
        Specifies a prefix for the variables, default is ''
    .EXAMPLE
        Set-SRVariablesFromJson -Path C:\Temp\Variables.json
    #>       
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=1)]
        [String]$Path,
        [Parameter(Mandatory=$false, Position=2)]
        [String]$Prefix="BH"
    )

    try {

        $VariablesJson = ConvertFrom-Json -InputObject (Get-Content -Path $Path -Raw)

        $VariableProperties = Get-Member -InputObject $VariablesJson -Type NoteProperty
    
        foreach ($VariableProperty in $VariableProperties) {                
                New-Item -Path Env:$Prefix$($VariableProperty.Name) -Value $($VariablesJson.$($VariableProperty.Name)) -Force | Out-Null    
        }

    } Catch {
            Write-Error "Can't set variables from JSON file `n$($_)"
            Throw "$($_.Exception.Message)"

    }
}
  
 function Get-PSDepend {
    
     Param(
         [Parameter(Mandatory=$true, Position=1)]
         [String]$Target
     )
 
     try {
 
     # Download and Load the PSDepend Module
         Save-Module -Name PSDepend -Path $Target
         Import-Module (Join-Path $Target PSDepend)
     
 
     } Catch {
             Write-Output "Can't get PSDepend `n$($_)"
             Throw $_
 
     }
 }


# Sets some environment variables required for the build.
New-Item -Path Env:BHBuildRoot -Value $PSScriptRoot -Force | Out-Null
New-Item -Path Env:BHProjectRoot -Value $((Get-Item $PSScriptRoot).Parent.FullName) -Force | Out-Null

Set-SRVariablesFromJson -Path (Join-Path $Env:BHBuildRoot 'variables.json')

New-Item -Path Env:BHWorkingDirPath -Value (Join-Path $Env:BHProjectRoot $ENV:BHWorkingDir) -Force | Out-Null          

# Create Dependency Target Path for dependency download
New-Item -Path Env:BHDependenciesFolderPath -Value (Join-Path $ENV:BHWorkingDirPath $ENV:BHDependenciesFolderName) -Force | Out-Null

if (-not (Test-Path -PathType Container -Path $ENV:BHWorkingDirPath)) {
    New-Item -Path $Env:BHWorkingDirPath -ItemType Container -Force | Out-Null              
}

# Create Dependencies folder
if (-not (Test-Path -PathType Container -Path $Env:BHDependenciesFolderPath)) {
    New-Item -Path $Env:BHDependenciesFolderPath -ItemType Container -Force | Out-Null               
}

Write-Build -Color Green "Listing build environment:"
Get-Childitem -Path Env:BH* | Sort-Object -Property Name

# In Appveyor? Show Appveyor environment
If($ENV:BHBuildSystem -eq 'AppVeyor')
{
    Get-ChildItem -Path Env:APPVEYOR_* | Sort-Object -Property Name
}
    
# Installs and Loads PSDepend
Get-PSDepend -Target $Env:BHDependenciesFolderPath