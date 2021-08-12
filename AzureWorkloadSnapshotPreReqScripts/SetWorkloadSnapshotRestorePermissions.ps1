#
# Copyright 2021 (c) Microsoft Corporation
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this script and associated documentation files (the "script"), to deal
# in the script without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the scipt, and to permit persons to whom the script is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the script.

# THE SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SCRIPT OR THE USE OR OTHER DEALINGS IN THE
# SCRIPT

<#
.SYNOPSIS
    Assign the required roles for the source virtual machine on the respective resource groups
    for workload snapshot backups.
    
.DESCRIPTION
    Assign the required roles for the source virtual machine on the respective resource groups
    for workload snapshot backups.

    Assigns Disk Backup Reader on the resource group which has virtual machine disks.
    Assigns Disk Snapshot Contributor on the resource group where workload snapshots will be created.

.PARAMETER Subscription
    Subscription Id for the virtual machine containing workload

.PARAMETER VirtualMachineResourceGroup
    Resource group for the virtual machine containing workload

.PARAMETER VirtualMachineName
    Virtual machine name containing workload

.PARAMETER DiskResourceGroups
    Resource group which contains the exisiting data disks or where new data disks are created

.PARAMETER SnapshotResourceGroup
    Target resource group for disk snapshots

.PARAMETER UserAssignedServiceIdentityId
    Service prinicipal id for user assigned service principal

.EXAMPLE
    C:\PS> .\SetWorkloadSnapshotRestorePermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName <VMName> `
            -DiskResourceGroups <DiskResourceGroupsName>,<DiskResourceGroupsName> `
            -SnapshotResourceGroup <SnapshotResourceGroupName>

.NOTES
    Author: Shashwat Trivedi (shtriv@microsoft.com)
#>

Param(
[parameter(Position= 0, Mandatory= $true)]
[string]
$Subscription,

[parameter(Position= 1, Mandatory= $true)]
[string]
$VirtualMachineResourceGroup,

[parameter(Position= 2 ,Mandatory= $true)]
[string]
$VirtualMachineName,

[parameter(Position= 3 ,Mandatory= $true)]
[string[]]
$DiskResourceGroups,

[parameter(Position= 4, Mandatory= $true)]
[string]
$SnapshotResourceGroup,

[parameter(Position= 5, Mandatory= $false)]
[string]
$UserAssignedServiceIdentityId = $null)

# Include helper functions
. ./AssignRoles.ps1

Write-Verbose "Connecting to Azure account"
Connect-AzAccount

Set-AzContext -SubscriptionId $Subscription
Write-Verbose "Azure context set for subscription $Subscription"

$principalId = $null

if ( [string]::IsNullOrEmpty($UserAssignedServiceIdentityId) -eq $false)
{
    Write-Verbose "Using user assigned service identity $UserAssignedServiceIdentityId"
    $principalId = $UserAssignedServiceIdentityId
}
else
{
    $vm = Get-AzVM -ResourceGroupName "$VirtualMachineResourceGroup" -Name "$VirtualMachineName"

    if ( [string]::IsNullOrEmpty($vm.Identity.PrincipalId) -eq $false)
    {
        Write-Verbose "System assigned identity enabled on virtual machine $VirtualMachineName"
        $principalId = $vm.Identity.PrincipalId
    }
    else
    {
        Write-Host "Enabling system assigned identity on virtual machine $VirtualMachineName"

        Update-AzVM -ResourceGroupName "$VirtualMachineResourceGroup" -VM $vm -IdentityType SystemAssigned
        Start-Sleep 10

        $vm = Get-AzVM -ResourceGroupName "$VirtualMachineResourceGroup" -Name "$VirtualMachineName"

        Write-Host "Enabled system assigned identity on virtual machine $VirtualMachineName"

        $principalId = $vm.Identity.PrincipalId
    }

    Write-Verbose "Using virtual machine system identity $principalId"
}

Write-Host "Assigning permissions to $principalId"

$diskSnapshotContributorRoleName = "Disk Snapshot Contributor"
$vmContributorRoleName = "Virtual Machine Contributor"
$diskRestoreOperatorRoleName = "Disk Restore operator"


# Assign permissions for disk resource groups
foreach ($DiskResourceGroup in $DiskResourceGroups)
{
    AssignRoleOnResourceGroup -PrincipalId $principalId -ResourceGroup $DiskResourceGroup -RoleName $diskRestoreOperatorRoleName
}

# Assign permissions for snapshot resource groups
AssignRoleOnResourceGroup -PrincipalId $principalId -ResourceGroup $SnapshotResourceGroup -RoleName $diskSnapshotContributorRoleName

# Assign permission on virtual machine
AssignRoleOnResource -PrincipalId $principalId -ResourceGroup $VirtualMachineResourceGroup -ResourceName $VirtualMachineName -ResourceType "Microsoft.Compute/virtualMachines" -RoleName $vmContributorRoleName

Write-Host "Script Execution completed"