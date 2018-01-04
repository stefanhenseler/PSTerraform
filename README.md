# PSBuildSecrets
This module implements some wrapper functions for terraform and azure cli 2.0. I use them in combination with other powershell based build tools like invoke-build or PSake.

[![Build status](https://ci.appveyor.com/api/projects/status/o2q8w3iqi58ouuwy?svg=true)](https://ci.appveyor.com/project/synax/psterraform)


# How to use
```Powershell
Invoke-Terraform -ArgumentList 'init' -Path <SomePath>
```

## Requirements
PSTerraform has the following requirements:
- Powershell 5.1 / 6.0.0-rc
    - [How to get Powershell](https://github.com/PowerShell/PowerShell)
- Azure CLI 2.0 +
    - [How to get Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Terraform
    - [Install Terraform](https://www.terraform.io/intro/getting-started/install.html)

## How to use
All commands are executed in a PowerShell session.
### Setup Key Vault

```Powershell

```

## ToDo
- Add usage examples to help
- Improve exception handling
