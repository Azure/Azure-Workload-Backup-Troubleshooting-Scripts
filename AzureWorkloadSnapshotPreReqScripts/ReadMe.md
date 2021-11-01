# Azure Workoad Snapshot Pre-Req Scripts

> Contains the scripts for setting up the permissions for virtual machine identity on required resources
> and resource group for snapshot backups dones by Azure workload backup extensions.



+ For Backup

Azure virtual machine containing the source workload requires the following roles 

Resource (Access control)  |Role   
------ | ------
Disk(s) attached to the source VM (or the Disk RG), that are getting snapshotted |Disk backup reader |
|Resource group (RG) in which the snapshots taken would be stored (specified at the time of creating backup policy) |Disk snapshot contributor  |

+ For Restore

Azure virtual machine containing the target workload requires the following roles 

Resource (Access control)  |Role   
------ | ------
|Resource group (RG) in which the snapshots taken would be stored (specified at the time of creating backup policy)   |Disk snapshot contributor  |
|Target Disk RG where all disks will be created during restore  |Disk Restore operator   |
|Source Disk RG (RG where all existing disks of target VM are present)   |Disk Restore operator   |
|Target VM     |Virtual Machine Contributor    |

+ For Snapshot deletion after retention period

Azure Backup Management Service requires the following roles

Resource (Access control)  |Role
------ | ------
|Resource group (RG) in which the snapshots taken would be stored (specified at the time of creating backup policy)   |Disk snapshot contributor  |

## Requirements

The following Powershell modules are required for the scripts

+ Az.Compute
+ Az.Accounts
+ Az.Resources

## Usage 

### Backup
Before the snapshot backup, use the following script to give the required roles to the virtual machine system identity

```powershell
.\SetWorkloadSnapshotBackupPermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName <SourceWorkloadVMName> `
            -DiskResourceGroups <DiskResourceGroupsName>,<DiskResourceGroupsName> `
            -SnapshotResourceGroup <SnapshotResourceGroupName>
```

Before the snapshot backup, use the following script to give the required roles to the user identity

```powershell
.\SetWorkloadSnapshotBackupPermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName <SourceWorkloadVMName> `
            -DiskResourceGroups <DiskResourceGroupsName>,<DiskResourceGroupsName> `
            -SnapshotResourceGroup <SnapshotResourceGroupName> `
            -UserAssignedServiceIdentityId <UserIdentityPrincipalId>
```

Run the following to get more help on the parameters
```powershell
Get-Help SetWorkloadSnapshotBackupPermissions.ps1
```

### Restore

Before the snapshot disk restore, use the following script to give the required roles to the virtual machine system identity

```powershell
.\SetWorkloadSnapshotRestorePermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName <SourceWorkloadVMName> `
            -DiskResourceGroups <DiskResourceGroupsName>,<DiskResourceGroupsName> `
            -SnapshotResourceGroup <SnapshotResourceGroupName>
```

Before the snapshot backup, use the following script to give the required roles to the user identity

```powershell
.\SetWorkloadSnapshotRestorePermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName <SourceWorkloadVMName> `
            -DiskResourceGroups <DiskResourceGroupsName>,<DiskResourceGroupsName> `
            -SnapshotResourceGroup <SnapshotResourceGroupName> `
            -UserAssignedServiceIdentityId <UserIdentityPrincipalId>
```

Run the following to get more help on the parameters
```powershell
Get-Help SetWorkloadSnapshotRestorePermissions.ps1
```
