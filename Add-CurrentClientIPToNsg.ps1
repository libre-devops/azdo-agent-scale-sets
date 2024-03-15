param (
    [string]$KeyVaultResourceId,
    [bool]$AddClientIPToFirewall = $true
)

function Update-KeyVaultNetworkRule
{
    param (
        [string]$KeyVaultName,
        [string]$ResourceGroupName,
        [bool]$AddClientIP
    )

    try
    {
        $keyVault = Get-AzKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName
        $currentNetworkAcls = $keyVault.NetworkAcls

        Write-Host "Fetching current IP rules for Key Vault: $KeyVaultName"
        $currentIps = $currentNetworkAcls.IpAddressRanges | ForEach-Object { $_ -replace '/32$', '' }
        Write-Host "Current IP rules: $( $currentIps -join ', ' )"

        $currentIp = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
        Write-Host "Current client IP: $currentIp"

        if ($AddClientIP)
        {
            if (-not($currentIps -contains $currentIp))
            {
                Write-Host "Appending current client IP to existing IP rules."
                $newIpRules = $currentIps + $currentIp
            }
            else
            {
                Write-Host "Current client IP already exists in Key Vault IP rules. No changes made."
                return
            }
        }
        else
        {
            if ($currentIps -contains $currentIp)
            {
                Write-Host "Removing current client IP from existing IP rules."
                $newIpRules = $currentIps | Where-Object { $_ -ne $currentIp }
            }
            else
            {
                Write-Host "Current client IP does not exist in Key Vault IP rules. No changes made."
                return
            }
        }

        Write-Host "Updating IP rules: $( $newIpRules -join ', ' )"
        $newIpRules = $newIpRules | ForEach-Object { "$_/32" }

        Update-AzKeyVaultNetworkRuleSet -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName `
            -IpAddressRange $newIpRules -Bypass $currentNetworkAcls.Bypass -DefaultAction $currentNetworkAcls.DefaultAction

        Write-Host "Key Vault network configuration updated."
    }
    catch
    {
        Write-Error "An error occurred: $_"
    }
}

try
{
    Write-Host "Starting script to update Key Vault firewall rules based on AddClientIPToFirewall flag."

    $resourceIdParts = $KeyVaultResourceId -split '/'
    $resourceGroupName = $resourceIdParts[4]
    $keyVaultName = $resourceIdParts[-1]

    if ($null -ne $keyVaultName)
    {
        Update-KeyVaultNetworkRule -KeyVaultName $keyVaultName -ResourceGroupName $resourceGroupName -AddClientIP $AddClientIPToFirewall
    }
    else
    {
        Write-Error "Key Vault Resource ID not properly supplied."
    }
}
catch
{
    Write-Error "An error occurred: $_"
}
