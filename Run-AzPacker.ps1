# Run-Packer.ps1 -WorkingDirectory "$(Get-Location)//packer/windows/windows-server2022-azure"

param (
    [string]$RunPackerInit = "true",
    [string]$RunPackerValidate = "true",
    [string]$RunPackerBuild = "true",
    [string]$PackerFileName = "packer.pkr.hcl",
    [string]$WorkingDirectory = (Get-Location).Path,
    [string]$PackerVersion = "default",
    [string]$NsgResourceId = $null,
    [string]$AddCurrentClientToNsg = "true",
    [string]$AttemptAzLogin = "true",
    [string]$RuleName = "TemporaryAllowCurrentClientIP",
    [int]$Priority = 105,
    [string]$Direction = "Inbound",
    [string]$Access = "Allow",
    [string]$Protocol = "Tcp",
    [string]$SourcePortRange = "*",
    [string]$DestinationPortRange = "*",
    [string]$DestinationAddressPrefix = "VirtualNetwork"
)

# Function to check if the Packer file exists
function Check-PackerFileExists
{
    $filePath = Join-Path -Path $WorkingDirectory -ChildPath $PackerFileName
    if (-not(Test-Path -Path $filePath))
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer file not found at $filePath. Exiting."
        exit 1
    }
    else
    {
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Packer file found at: $filePath" -ForegroundColor Green
    }
}

function New-Password
{
    param (
        [int] $length = 16,
        [string] $alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+<>,.?/:;~`-='
    )
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rng.GetBytes($bytes)
    $value = [system.numerics.BigInteger]::Abs([bigint]$bytes)
    $result = New-Object char[]($length)

    $base = $alphabet.Length
    for ($i = 0; $i -lt $length; $i++) {
        $remainder = $value % $base
        $value = $value / $base
        $result[$i] = $alphabet[$remainder]
    }
    return (-join $result)
}

# Function to check if Tfenv is installed
function Check-PkenvExists
{
    try
    {
        $pkenvPath = Get-Command pkenv -ErrorAction Stop
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: pkenv found at: $( $pkenvPath.Source )" -ForegroundColor Green
        return $true
    }
    catch
    {
        Write-Warning "[$( $MyInvocation.MyCommand.Name )] Warning: pkenv is not installed or not in PATH. Skipping version checking."
        return $false
    }
}

# Function to check if Packer is installed
function Check-PackerExists
{
    try
    {
        $packerPath = Get-Command packer -ErrorAction Stop
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Packer found at: $( $packerPath.Source )" -ForegroundColor Green
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer is not installed or not in PATH. Exiting."
        exit 1
    }
}

# Function to ensure the desired version of Packer is installed
function Ensure-PackerVersion
{
    # Check if the specified version is already installed
    $pkrVersion = $PackerVersion.ToLower()
    if ($pkrVersion -ne 'default')
    {
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Packer version is set to '$PackerVersion', running install and use" -ForegroundColor Green
        pkenv install $pkrVersion
        pkenv use $pkrVersion
    }
    else
    {
        try
        {
            Write-Information "[$( $MyInvocation.MyCommand.Name )] Info: Installing Packer version $Version using pkenv..."
            pkenv install $Version
            pkenv use $Version
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Installed and set Packer version $Version" -ForegroundColor Green
        }
        catch
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Failed to install Packer version $Version"
            exit 1
        }
    }
}



# Function to convert string to boolean
function Convert-ToBoolean($value)
{
    $valueLower = $value.ToLower()
    if ($valueLower -eq "true")
    {
        return $true
    }
    elseif ($valueLower -eq "false")
    {
        return $false
    }
    else
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Invalid value - $value. Exiting."
        exit 1
    }
}

function Connect-AzAccountWithServicePrincipal
{
    param (
        [string]$ApplicationId,
        [string]$TenantId,
        [string]$Secret,
        [string]$SubscriptionId
    )

    try
    {
        $SecureSecret = $Secret | ConvertTo-SecureString -AsPlainText -Force
        $Credential = New-Object System.Management.Automation.PSCredential ($ApplicationId, $SecureSecret)
        Connect-AzAccount -ServicePrincipal -Credential $Credential -Tenant $TenantId -ErrorAction Stop

        if (-not [string]::IsNullOrEmpty($SubscriptionId))
        {
            Set-AzContext -SubscriptionId $SubscriptionId
        }

        Write-Host "[$( $MyInvocation.MyCommand.Name )] Success: Successfully logged in to Azure." -ForegroundColor Cyan
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Failed to log in to Azure with the provided service principal details: $_"
        throw $_
    }
}


function Manage-CurrentIPInNsg
{
    param (
        [Microsoft.Azure.Commands.Network.Models.PSNetworkSecurityGroup]$Nsg,
        [bool]$AddRule,
        [string]$RuleName,
        [int]$Priority,
        [string]$Direction,
        [string]$Access,
        [string]$Protocol,
        [string]$SourcePortRange,
        [string]$DestinationPortRange,
        [string]$DestinationAddressPrefix
    )

    try
    {
        if ($AddRule)
        {
            $currentIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
            if (-not$currentIp)
            {
                Write-Error "[$( $MyInvocation.MyCommand.Name )] Failed to obtain current IP."
                return
            }

            $sourceAddressPrefix = $currentIp

            # Check if the rule already exists
            $existingRule = $Nsg.SecurityRules | Where-Object { $_.Name -eq $RuleName }

            if ($existingRule)
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Rule $RuleName already exists. Updating it with the new IP address." -ForegroundColor Green
                # Remove existing rule to update
                $Nsg.SecurityRules.Remove($existingRule)
            }

            # Adding the rule
            $rule = New-AzNetworkSecurityRuleConfig -Name $RuleName `
                                                    -Access $Access `
                                                    -Protocol $Protocol `
                                                    -Direction $Direction `
                                                    -Priority $Priority `
                                                    -SourceAddressPrefix $sourceAddressPrefix `
                                                    -SourcePortRange $SourcePortRange `
                                                    -DestinationAddressPrefix $DestinationAddressPrefix `
                                                    -DestinationPortRange $DestinationPortRange
            $Nsg.SecurityRules.Add($rule)

            Write-Host "[$( $MyInvocation.MyCommand.Name )] Rule $RuleName has been added/updated successfully." -ForegroundColor Green
        }
        else
        {
            # Removing the rule
            $existingRule = $Nsg.SecurityRules | Where-Object { $_.Name -eq $RuleName }
            if ($existingRule)
            {
                $Nsg.SecurityRules.Remove($existingRule)
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Rule $RuleName has been removed successfully." -ForegroundColor Green
            }
            else
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Rule $RuleName does not exist. No action needed." -ForegroundColor Yellow
            }
        }

        # Applying changes to the NSG
        Set-AzNetworkSecurityGroup -NetworkSecurityGroup $Nsg
        Write-Host "[$( $MyInvocation.MyCommand.Name )] NSG has been updated successfully." -ForegroundColor Green
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] An error occurred: $_"
    }
}

function Run-PackerInit
{
    if ($RunPackerInit -eq $true)
    {
        try
        {
            if ($isWindows)
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Packer init in $WorkingDirectory" -ForegroundColor Green
                packer init -upgrade $PackerFileName | Out-Host
                if ($LASTEXITCODE -eq 0)
                {
                    return $true
                }
                else
                {
                    Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer init failed with exit code $LASTEXITCODE"
                    return $false
                }
            }
            else
            {
                Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Packer init in $WorkingDirectory" -ForegroundColor Green
                packer init -force $PackerFileName | Out-Host
                if ($LASTEXITCODE -eq 0)
                {
                    return $true
                }
                else
                {
                    Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer init failed with exit code $LASTEXITCODE"
                    return $false
                }
            }
        }
        catch
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer init encountered an exception"
            return $false
        }
    }
    return $false
}


function Run-PackerValidate
{
    if ($RunPackerValidate -eq $true)
    {
        try
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Packer validate in $WorkingDirectory" -ForegroundColor Green
            packer validate $PackerFileName | Out-Host
            if ($LASTEXITCODE -eq 0)
            {
                return $true
            }
            else
            {
                Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer validate failed with exit code $LASTEXITCODE"
                return $false
            }
        }
        catch
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer validate encountered an exception"
            return $false
        }
    }
    return $false
}

function Run-PackerBuild
{
    if ($RunPackerBuild -eq $true)
    {
        try
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Info: Running Packer build in $WorkingDirectory" -ForegroundColor Green
            packer build $PackerFileName | Out-Host
            if ($LASTEXITCODE -eq 0)
            {
                return $true
            }
            else
            {
                Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer build failed with exit code $LASTEXITCODE"
                return $false
            }
        }
        catch
        {
            Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Packer build encountered an exception"
            return $false
        }
    }
    return $false
}


try
{
    $ConvertedAddCurrentClientToNsg = Convert-ToBoolean $AddCurrentClientToNsg
    $ConvertedAttemptAzLogin = Convert-ToBoolean $AttemptAzLogin
    if ($ConvertedAttemptAzLogin)
    {
        Connect-AzAccountWithServicePrincipal -ApplicationId $env:PKR_VAR_ARM_CLIENT_ID -TenantId $Env:PKR_VAR_ARM_TENANT_ID -Secret $Env:PKR_VAR_ARM_CLIENT_SECRET -SubscriptionId $Env:PKR_VAR_ARM_SUBSCRIPTION_ID
    }

    if ($null -ne $NsgResourceId)
    {
        # Extract Resource Group Name and NSG Name from the Resource ID
        $resourceIdParts = $NsgResourceId -split '/'
        $resourceGroupName = $resourceIdParts[4]
        $nsgName = $resourceIdParts[-1]

        # Retrieve the NSG object
        $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName

        Manage-CurrentIPInNsg -Nsg $nsg `
                              -AddRule $ConvertedAddCurrentClientToNsg `
                              -RuleName $RuleName `
                              -Priority $Priority `
                              -Direction $Direction `
                              -Access $Access `
                              -Protocol $Protocol `
                              -SourcePortRange $SourcePortRange `
                              -DestinationPortRange $DestinationPortRange `
                              -DestinationAddressPrefix $DestinationAddressPrefix
    }
    else
    {
        Write-Information "[$( $MyInvocation.MyCommand.Name )] NSG ID not supplied, so not editing the NSG"
    }
    # Convert string parameters to boolean
    $RunPackerInit = Convert-ToBoolean $RunPackerInit
    $RunPackerValidate = Convert-ToBoolean $RunPackerValidate
    $RunPackerBuild = Convert-ToBoolean $RunPackerBuild

    if ($RunPackerInit -eq $false)
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: You must run packer init to use this script, it does not support false use of it at this time."
        exit 1
    }
    # Change to the specified working directory
    try
    {
        $CurrentWorkingDirectory = (Get-Location).path
        Set-Location -Path $WorkingDirectory
    }
    catch
    {
        Write-Error "[$( $MyInvocation.MyCommand.Name )] Error: Unable to change to directory: $WorkingDirectory"
        exit 1
    }

    Check-PackerFileExists

    # Execution flow
    $initSuccess = Run-PackerInit
    if ($initSuccess -eq $true)
    {
        $validateSuccess = Run-PackerValidate
        $packerPassword = New-Password
        Set-Item -Path Env:PKR_VAR_install_password -Value $packerPassword

        if ($validateSuccess -eq $true)
        {
            Run-PackerBuild
        }
        else
        {
            Write-Host "[$( $MyInvocation.MyCommand.Name )] Packer validate failed. Skipping Packer build."
        }
    }
    else
    {
        Write-Host "[$( $MyInvocation.MyCommand.Name )] Packer init failed. Skipping Packer validate and Packer build."
    }

}
catch
{
    Write-Error "[$( $MyInvocation.MyCommand.Name )] An error occurred: $_"
}
finally
{
    if ($null -ne $NsgResourceId)
    {
        # Extract Resource Group Name and NSG Name from the Resource ID
        $resourceIdParts = $NsgResourceId -split '/'
        $resourceGroupName = $resourceIdParts[4]
        $nsgName = $resourceIdParts[-1]

        # Retrieve the NSG object
        $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName
        Manage-CurrentIPInNsg -Nsg $nsg `
                              -AddRule $false `
                              -RuleName $RuleName `
                              -Priority $Priority `
                              -Direction $Direction `
                              -Access $Access `
                              -Protocol $Protocol `
                              -SourcePortRange $SourcePortRange `
                              -DestinationPortRange $DestinationPortRange `
                              -DestinationAddressPrefix $DestinationAddressPrefix
    }
    else
    {
        Write-Information "[$( $MyInvocation.MyCommand.Name )] NSG ID not supplied, so not editing the NSG"
    }
    Set-Location $CurrentWorkingDirectory
}
