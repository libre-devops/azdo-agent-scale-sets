param (
    [Parameter(Mandatory = $true)]
    [string]$NsgResourceId,

    [bool]$AddCurrentClientToNsg = $true,
    [string]$RuleName = "TemporaryAllowCurrentClientIP",
    [int]$Priority = 105,
    [string]$Direction = "Inbound",
    [string]$Access = "Allow",
    [string]$Protocol = "Tcp",
    [string]$SourcePortRange = "*",
    [string]$DestinationPortRange = "*",
    [string]$DestinationAddressPrefix = "VirtualNetwork"
)

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
                Write-Error "Failed to obtain current IP."
                return
            }

            $sourceAddressPrefix = $currentIp

            # Check if the rule already exists
            $existingRule = $Nsg.SecurityRules | Where-Object { $_.Name -eq $RuleName }

            if ($existingRule)
            {
                Write-Host "Rule $RuleName already exists. Updating it with the new IP address."
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

            Write-Host "Rule $RuleName has been added/updated successfully."
        }
        else
        {
            # Removing the rule
            $existingRule = $Nsg.SecurityRules | Where-Object { $_.Name -eq $RuleName }
            if ($existingRule)
            {
                $Nsg.SecurityRules.Remove($existingRule)
                Write-Host "Rule $RuleName has been removed successfully."
            }
            else
            {
                Write-Host "Rule $RuleName does not exist. No action needed."
            }
        }

        # Applying changes to the NSG
        Set-AzNetworkSecurityGroup -NetworkSecurityGroup $Nsg
        Write-Host "NSG has been updated successfully."
    }
    catch
    {
        Write-Error "An error occurred: $_"
    }
}

# Main execution block
try
{
    # Extract Resource Group Name and NSG Name from the Resource ID
    $resourceIdParts = $NsgResourceId -split '/'
    $resourceGroupName = $resourceIdParts[4]
    $nsgName = $resourceIdParts[-1]

    # Retrieve the NSG object
    $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName

    if ($null -ne $nsg)
    {
        Manage-CurrentIPInNsg -Nsg $nsg `
                              -AddRule $AddCurrentClientToNsg `
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
        Write-Error "Failed to retrieve the NSG with Resource ID: $NsgResourceId"
    }
}
catch
{
    Write-Error "An error occurred: $_"
}
