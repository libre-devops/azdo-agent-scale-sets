<#
.SYNOPSIS
    This PowerShell script automates tasks related to Packer, including initialization, validation, and build processes.

.DESCRIPTION
    'Run-Packer.ps1' is a PowerShell script designed to streamline the use of HashiCorp's Packer tool. It checks for the necessary environment setup, such as the presence of the Packer executable and required files, and then proceeds to perform initialization, validation, and building of Packer configurations. The script is configurable via parameters to control the execution of these stages.

.PARAMETERS
    RunPackerInit
        Specifies whether to run the Packer initialization process. Accepts 'true' or 'false'.

    RunPackerValidate
        Specifies whether to run the Packer validation process. Accepts 'true' or 'false'.

    RunPackerBuild
        Specifies whether to run the Packer build process. Accepts 'true' or 'false'.

    PackerFileName
        The name of the Packer file to be used, typically a .pkr.hcl file.

    WorkingDirectory
        The working directory where the Packer file is located and where Packer commands will be executed.

    DebugMode
        Enables or disables debug mode. Accepts 'true' or 'false'.

    PackerVersion
        Specifies the version of Packer to use. Default is 'latest'.

.FUNCTIONS
    Check-PackerFileExists
        Checks if the specified Packer file exists in the working directory.

    Check-PkenvExists
        Verifies the presence of pkenv, a Packer version management tool.

    Check-PackerExists
        Checks if Packer is installed and available in the system's PATH.

    Ensure-PackerVersion
        Ensures that the desired version of Packer is installed using pkenv.

    Convert-ToBoolean
        Converts string parameters to boolean values.

    Run-PackerInit
        Runs the 'packer init' command with the specified options.

    Run-PackerValidate
        Executes the 'packer validate' command for the Packer file.

    Run-PackerBuild
        Performs the 'packer build' process using the specified Packer file.

.EXAMPLE
    .\Run-Packer.ps1 -RunPackerInit "true" -RunPackerValidate "true" -RunPackerBuild "true" -PackerFileName "example.pkr.hcl"

    This example runs the script with all Packer processes enabled using the 'example.pkr.hcl' file.

.NOTES
    Ensure that all prerequisites, such as Packer and pkenv, are installed and properly configured before running this script.
    Modify the script parameters based on your specific Packer setup and requirements.

    Author: Craig Thacker
    Date: 11/12/2023
#>

param (
    [string]$RunPackerInit = "true",
    [string]$RunPackerValidate = "true",
    [string]$RunPackerBuild = "true",
    [string]$PackerFileName = "packer.pkr.hcl",
    [string]$WorkingDirectory = (Get-Location).Path,
    [string]$DebugMode = "false",
    [string]$PackerVersion = "default"
)

# Function to check if the Packer file exists
function Check-PackerFileExists {
    $filePath = Join-Path -Path $WorkingDirectory -ChildPath $PackerFileName
    if (-not (Test-Path -Path $filePath)) {
        Write-Error "Error: Packer file not found at $filePath. Exiting."
        exit 1
    }
    else {
        Write-Host "Success: Packer file found at: $filePath" -ForegroundColor Green
    }
}

function New-Password {
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
    for ($i = 0 ; $i -lt $length ; $i++) {
        $remainder = $value % $base
        $value = $value / $base
        $result[$i] = $alphabet[$remainder]
    }
    return (-join $result)
}

# Function to check if Tfenv is installed
function Check-PkenvExists {
    try {
        $pkenvPath = Get-Command pkenv -ErrorAction Stop
        Write-Host "Success: pkenv found at: $($pkenvPath.Source)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Warning: pkenv is not installed or not in PATH. Skipping version checking."
        return $false
    }
}

# Function to check if Packer is installed
function Check-PackerExists {
    try {
        $packerPath = Get-Command packer -ErrorAction Stop
        Write-Host "Success: Packer found at: $($packerPath.Source)" -ForegroundColor Green
    }
    catch {
        Write-Error "Error: Packer is not installed or not in PATH. Exiting."
        exit 1
    }
}

# Function to ensure the desired version of Packer is installed
function Ensure-PackerVersion {
    # Check if the specified version is already installed
    $pkrVersion = $PackerVersion.ToLower()
    if ($pkrVersion -ne 'default') {
        Write-Host "Success: Packer version is set to '$PackerVersion', running install and use" -ForegroundColor Green
        pkenv install $pkrVersion
        pkenv use $pkrVersion
    }
    else {
        try {
            Write-Information "Info: Installing Packer version $Version using pkenv..."
            pkenv install $Version
            pkenv use $Version
            Write-Host "Success: Installed and set Packer version $Version" -ForegroundColor Green
        }
        catch {
            Write-Error "Error: Failed to install Packer version $Version"
            exit 1
        }
    }
}

# Function to convert string to boolean
function Convert-ToBoolean($value) {
    $valueLower = $value.ToLower()
    if ($valueLower -eq "true") {
        return $true
    }
    elseif ($valueLower -eq "false") {
        return $false
    }
    else {
        Write-Error "Error: Invalid value - $value. Exiting."
        exit 1
    }
}

$pkenvExists = Check-PkenvExists
if ($pkenvExists) {
    Ensure-PackerVersion -Version $PackerVersion
}

if (Check-PackerFileExists) {
    $filePath = Join-Path -Path $WorkingDirectory -ChildPath $PackerFileName
}

# Convert string parameters to boolean
$RunPackerInit = Convert-ToBoolean $RunPackerInit
$RunPackerValidate = Convert-ToBoolean $RunPackerValidate
$RunPackerBuild = Convert-ToBoolean $RunPackerBuild
$DebugMode = Convert-ToBoolean $DebugMode

# Enable debug mode if DebugMode is set to $true
if ($DebugMode) {
    $DebugPreference = "Continue"
}

# Diagnostic output
Write-Debug "RunPackerInit: $RunPackerinit"
Write-Debug "RunPackerValidate: $RunPackerValidate"
Write-Debug "RunPackerBuild: $RunPackerBuild"
Write-Debug "DebugMode: $DebugMode"


if ($RunPackerInit -eq $false) {
    Write-Error "Error: You must run packer init to use this script, it does not support false use of it at this time."
    exit 1
}

# Change to the specified working directory
try {
    $CurrentWorkingDirectory = (Get-Location).path
    Set-Location -Path $WorkingDirectory
}
catch {
    Write-Error "Error: Unable to change to directory: $WorkingDirectory"
    exit 1
}

Check-PackerFileExists

function Run-PackerInit {
    if ($RunPackerInit -eq $true) {
        try {
            if ($isWindows) {
                Write-Host "Info: Running Packer init in $WorkingDirectory" -ForegroundColor Green
                packer init -upgrade $PackerFileName | Out-Host
                if ($LASTEXITCODE -eq 0) {
                    return $true
                }
                else {
                    Write-Error "Error: Packer init failed with exit code $LASTEXITCODE"
                    return $false
                }
            }
            else {
                Write-Host "Info: Running Packer init in $WorkingDirectory" -ForegroundColor Green
                packer init -force $PackerFileName | Out-Host
                if ($LASTEXITCODE -eq 0) {
                    return $true
                }
                else {
                    Write-Error "Error: Packer init failed with exit code $LASTEXITCODE"
                    return $false
                }
            }
        }
        catch {
            Write-Error "Error: Packer init encountered an exception"
            return $false
        }
    }
    return $false
}


function Run-PackerValidate {
    if ($RunPackerValidate -eq $true) {
        try {
            Write-Host "Info: Running Packer validate in $WorkingDirectory" -ForegroundColor Green
            packer validate $PackerFileName | Out-Host
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
            else {
                Write-Error "Error: Packer validate failed with exit code $LASTEXITCODE"
                return $false
            }
        }
        catch {
            Write-Error "Error: Packer validate encountered an exception"
            return $false
        }
    }
    return $false
}

function Run-PackerBuild {
    if ($RunPackerBuild -eq $true) {
        try {
            Write-Host "Info: Running Packer build in $WorkingDirectory" -ForegroundColor Green
            packer build $PackerFileName | Out-Host
            if ($LASTEXITCODE -eq 0) {
                return $true
            }
            else {
                Write-Error "Error: Packer build failed with exit code $LASTEXITCODE"
                return $false
            }
        }
        catch {
            Write-Error "Error: Packer build encountered an exception"
            return $false
        }
    }
    return $false
}

# Execution flow
$initSuccess = Run-PackerInit
if ($initSuccess -eq $true) {
    $validateSuccess = Run-PackerValidate
    $packerPassword = New-Password
    Set-Item -Path Env:PKR_VAR_install_password -Value $packerPassword

    if ($validateSuccess -eq $true) {
        Run-PackerBuild
    }
    else {
        Write-Host "Packer validate failed. Skipping Packer build."
    }
}
else {
    Write-Host "Packer init failed. Skipping Packer validate and Packer build."
}


Set-Location $CurrentWorkingDirectory
