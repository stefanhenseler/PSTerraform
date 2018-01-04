# Synopsis: Build the project.
Param(

)

# Synopsis: initializes the build environment
task init {
    
    Write-Build -Color Green "Bootstraping Build Environment..."
    # Invoke bootstrap in order to get PSDepend from artifactory.
    $BootstrapHelper = Join-Path $PSScriptRoot .\Invoke-Bootstrap.ps1
    .$BootstrapHelper
    
    # Invoke PSDepend to download and load all dependencies
    Write-Build -Color Green "Loading Dependencies..."
    Invoke-PSDepend -Force -Target $Env:BHDependenciesFolderPath -Import -Install 
    
    if ($Env:Path -notlike '*$ENV:BHDependenciesFolderPath*') {
        $ENV:PATH += ";$ENV:BHDependenciesFolderPath"
    }        
    
    # Load Build Environment using BuildHelper Module function
    Set-BuildEnvironment -Force    

    # The test result NUnit target folder.
    Set-Item -Path ENV:BHTestResultTargetPath -Value (Join-Path $ENV:BHWorkingDirPath $ENV:BHTestResultFolderName) -Force | Out-Null    

    # Find the full path to the module manifest in the project folder
    Set-Item -Path ENV:BHSourceRootPath -Value (Get-ChildItem $ENV:BHProjectRoot -Directory $ENV:BHSourceRootName).FullName -Force | Out-Null     
    Set-Item -Path ENV:BHModuleManifest -Value (Get-ChildItem -Path $ENV:BHSourceRootPath -Filter "*.psd1").FullName -Force | Out-Null    

    # Find the module name
    Set-Item -Path ENV:BHModuleName -Value (Get-Item -Path $ENV:BHModuleManifest).BaseName -Force | Out-Null    
    Set-Item -Path Env:BHModuleRootPath -Value (Join-Path $ENV:BHWorkingDirPath $ENV:BHModuleName) -Force | Out-Null    
    Set-Item -Path ENV:BHRepositoryPath -Value (Join-Path $ENV:BHWorkingDirPath $ENV:BHRepositoryName) -Force | Out-Null    

    # Variables for logging and testing
    Set-Item -Path ENV:BHTimeStamp -Value (Get-Date -UFormat "%Y%m%d-%H%M%S")
    Set-Item -Path ENV:BHPSVersion -Value $PSVersionTable.PSVersion.Major
    Set-Item -Path ENV:BHTestFile -Value "TestResults_PS$PSVersion`_$TimeStamp.xml"

    Write-Build -Color Green "Listing build environment:"
    Get-Childitem -Path Env:BH* | Sort-Object -Property Name

    # In Appveyor? Show Appveyor environment
    If($ENV:BHBuildSystem -eq 'AppVeyor')
    {
        Get-ChildItem -Path Env:APPVEYOR_* | Sort-Object -Property Name
    }

}

# Synopsis: Runs test cases against the environment
task test {
    
        # Create Results folder if required.
        if (-not (Test-Path -Path $ENV:BHTestResultTargetPath -PathType Container)) { 
            New-Item -Path $ENV:BHTestResultTargetPath -ItemType Directory -Force
        }
    
        # Gather test results. Store them in a variable and file
        $TestResults = Invoke-Gherkin -Path $ENV:BHProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile (Join-Path $ENV:BHTestResultTargetPath $ENV:BHTestFile)

        # In Appveyor?  Upload our tests! #Abstract this into a function?
        If($ENV:BHBuildSystem -eq 'AppVeyor')
        {
             $Results = Get-ChildItem $ENV:BHTestResultTargetPath -Filter '*.xml'
             
             foreach ($Result in $Results) { 
                (New-Object 'System.Net.WebClient').UploadFile(
                    "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
                    $Result.FullName )
             }
        }
    
        # Failed tests?
        # Need to tell psake or it will proceed to the deployment. Danger!
        if($TestResults.FailedCount -gt 0)
        {
            Throw "Failed '$($TestResults.FailedCount)' tests, build failed"
        } 
    
    }


# Synopsis: Provision task for build automation.
task build {

    try {        

        # We copy the source in to the working directory
        Write-Build -Color Green "Copy module root folder to match module name: from [$ENV:BHSourceRootPath] to [$ENV:BHModuleRootPath]"
        if (Test-Path -Path $ENV:BHModuleRootPath -PathType Container) {
            Remove-Item -Recurse -Force -Path $ENV:BHModuleRootPath
        }
        Copy-Item -Path $ENV:BHSourceRootPath -Destination $ENV:BHModuleRootPath -Force -Recurse
        
# First we update the FunctionsToExport in the powershell module. This allows us to dot source the module functions and still autodiscover module cmdlets
        Write-Build -Color Green "Update FunctionsToExport in module manifest"

        $ManifestPath = ((Get-ChildItem -Path $ENV:BHModuleRootPath -Filter '*.psd1').FullName)
          
        Write-Build -Color Green "Attempting to add functions of module [$ManifestPath] to FunctionsToExport property"
        Write-Build -Color Green "Module root path is [$ENV:BHModuleRootPath]"

        $PublicFunctions = $(Get-ChildItem "$ENV:BHModuleRootPath\Public" -Filter *.ps1 -Recurse).BaseName             
        $FunctionToExportString = -join $($PublicFunctions | ForEach-Object { $("'" + $_ + "',") } ) -replace [Regex]'.$','' 
        Write-Build -Color Green "New FunctionsToExport string is [$FunctionToExportString]"          

        Write-Build -Color Green "Getting content of [$ManifestPath]"
        $ModuleManifestContent = Get-Content $ManifestPath

        Write-Build -Color Green "Setting [FunctionsToExport] to [$FunctionToExportString]"
        $NewModuleManifestContent = $ModuleManifestContent -replace '^(FunctionsToExport =).*', "`$1 $FunctionToExportString"
        
        If ($ENV:BHBuildSystem -eq 'AppVeyor') { 
            Write-Build -Color Green "Setting [ModuleVersion] to [$env:APPVEYOR_BUILD_VERSION]"
            $NewModuleManifestContent = $ModuleManifestContent -replace '^(ModuleVersion =).*', "`$1 '$env:APPVEYOR_BUILD_VERSION'"
        
        }
        
        $NewModuleManifestContent | Set-Content $ManifestPath

        # We have to create a local folder for the local repository
        Write-Build -Color Green "Create folder for local staging repository: [$ENV:BHRepositoryPath]"
        if (Test-Path -Path $ENV:BHRepositoryPath) {
            Remove-Item -Recurse -Force -Path $ENV:BHRepositoryPath
        }        
        New-Item -ItemType Directory -Path $ENV:BHRepositoryPath | Out-Null
      
        Write-Build -Color Green "Register PSRepository with Source and Publish Location [$ENV:BHRepositoryPath]"
        # First we unregister the repo if it is still registered.
        Get-PSRepository | Where-Object 'Name' -eq $ENV:BHRepositoryName | Unregister-PSRepository 
        # Register Repostiory so we can publish the module to a local folder. This is required so we can use Bamboo to publish the module to artifactory.
        Register-PSRepository -Name $ENV:BHRepositoryName -SourceLocation $ENV:BHRepositoryPath -PublishLocation $ENV:BHRepositoryPath -InstallationPolicy Trusted
              
        Write-Build -Color Green "Publish Module to PSRepository [$($ENV:BHRepositoryName)]"
        
        Publish-Module -Path $ENV:BHModuleRootPath -Repository $ENV:BHRepositoryName -Verbose

    } catch {
        Throw "Error when bulding PowerShell module.`n$_"
    }
   
}

task deploy {
    # We only deploy via appveyor
    If ($ENV:BHBuildSystem -eq 'AppVeyor') { 
        Publish-Module -Path $ENV:BHModuleRootPath -Repository PSGallery -Verbose -NuGetApiKey $Env:NugetApiKey
    }

}

# Synopsis: Remove temporary files.
task clean {

    Write-Build -Color Green "Unregister PSRepository [$($ENV:BHRepositoryName)]"
    Get-PSRepository | Where-Object 'Name' -eq $ENV:BHRepositoryName | Unregister-PSRepository 
    
}

# Synopsis: This is the default task which executes all tasks in order
task . init, test, build, deploy


