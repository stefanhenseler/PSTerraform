@{
    #Global Options
    PSDependOptions = @{
        Parameters = @{
            Repository = 'PSGallery'
        }        
    }

  # Powershell Modules

    'powershell-yaml' = 'latest'
    BuildHelpers = 'latest'
    'Pester' = 'latest'


  # File
   nuget = @{
        DependencyType = 'FileDownload'
        Source = 'https://nuget.org/nuget.exe'
    }
}
