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
    Resource group which contains the data disks

.PARAMETER SnapshotResourceGroup
    Target resource group for disk snapshots

.PARAMETER UserAssignedServiceIdentityId
    Service prinicipal id for user assigned service principal

.EXAMPLE
    C:\PS> .\SetWorkloadSnapshotBackupPermissions.ps1 -Subscription <SubscriptionId> `
                -VirtualMachineResourceGroup <VMResourceGroup> `
                -VirtualMachineName @(<SourceWorkloadVMName1>,<SourceWorkloadVMName2>) `
                -DiskResourceGroups @(<DiskResourceGroupsName1>,<DiskResourceGroupsName2>) `
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
[string[]]
$VirtualMachineNames,

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
. ./AssignIdentity.ps1

Write-Verbose "Connecting to Azure account"
Connect-AzAccount

Set-AzContext -SubscriptionId $Subscription
Write-Verbose "Azure context set for subscription $Subscription"

$diskBackupReaderRoleName = "Disk Backup Reader"
$diskSnapshotContributorRoleName = "Disk Snapshot Contributor"
$backupServicePrincipalId = (Get-AzADServicePrincipal -SearchString 'Backup Management Service').Id

Write-Host "Assigning identity to $VirtualMachineNames" -ForegroundColor Blue
$principalIds = AssignIdentityToVMs -UserAssignedServiceIdentityId $UserAssignedServiceIdentityId -VirtualMachineResourceGroup $VirtualMachineResourceGroup -VirtualMachineNames $VirtualMachineNames
Write-Host "Assigning permissions to $principalIds" -ForegroundColor Blue

foreach ($principalId in $principalIds)
{
    # Assign permissions for disk resource groups
    foreach ($DiskResourceGroup in $DiskResourceGroups)
    {
        AssignRoleOnResourceGroup -PrincipalId $principalId -ResourceGroup $DiskResourceGroup -RoleName $diskBackupReaderRoleName
    }

    # Assign permissions for snapshot resource groups to VM Identity
    AssignRoleOnResourceGroup -PrincipalId $principalId -ResourceGroup $SnapshotResourceGroup -RoleName $diskSnapshotContributorRoleName
}

Write-Host "Assigning permissions to Azure Backup Management Service" -ForegroundColor Blue

# Assign permissions for snapshot resource groups to Backup Management Service
AssignRoleOnResourceGroup -PrincipalId $backupServicePrincipalId -ResourceGroup $SnapshotResourceGroup -RoleName $diskSnapshotContributorRoleName

Write-Host "Script Execution completed" -ForegroundColor Green