# Azure Workoad Snapshot Pre-Req Scripts

> Azure Backup requires permissions to perform snapshots on disks and place them in user specified resource groups. These permissions are inherited via the MSI 
> associated with that virtual machine. The below scripts help the user set the required permissions to the MSI associated with that VM at relevant scopes.

+ For Backup

Azure virtual machine containing the source workload requires the following roles 

Resource (Access control)  |Role   
------ | ------
Disk(s) attached to the source VM for which snapshot needs to be taken. For ease-of-use, we ask the user for the disk RG so that the process need not be repeated if new disks are added in the future under the same RG |Disk backup reader |
|Resource group (RG) in which the disk snapshots would be stored (specified at the time of creating backup policy) |Disk snapshot contributor  |

+ For Restore

Azure virtual machine containing the target workload requires the following roles 

Resource (Access control)  |Role   
------ | ------
|Resource group (RG) in which the snapshots taken would be stored (specified at the time of creating backup policy)   |Disk snapshot contributor  |
|Target Disk RG where all disks will be created during restore  |Disk Restore operator   |
|Attached Disk RG (RG where all existing disks of target VM are present)   |Disk Restore operator   |
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
If you are using system-assigned identity for the backed up VM, use the following script to give the required roles to the virtual machine system identity, before configuring the snapshot backup. Once configured, snapshot backups will be taken as per policy by Azure Backup service.

```powershell
.\SetWorkloadSnapshotBackupPermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName @(<SourceWorkloadVMName1>,<SourceWorkloadVMName2>) `
            -DiskResourceGroups @(<DiskResourceGroupsName1>,<DiskResourceGroupsName2>) `
            -SnapshotResourceGroup <SnapshotResourceGroupName>
```

If you are using user-assigned identity for the backed up VM, use the following script to give the required roles to the virtual machine use-assigned identity, before configuring the snapshot backup. Once configured, snapshot backups will be taken as per policy by Azure Backup service.

```powershell
.\SetWorkloadSnapshotBackupPermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName @(<SourceWorkloadVMName1>,<SourceWorkloadVMName2>) `
            -DiskResourceGroups @(<DiskResourceGroupsName1>,<DiskResourceGroupsName2>) `
            -SnapshotResourceGroup <SnapshotResourceGroupName> `
            -UserAssignedServiceIdentityId <UserIdentityPrincipalARMId>
```

Run the following to get more help on the parameters
```powershell
Get-Help SetWorkloadSnapshotBackupPermissions.ps1
```

### Restore

If you are using user-assigned identity for the target VM, use the following script to give the required roles to the target virtual machine system identity, before triggering the snapshot restore.

```powershell
.\SetWorkloadSnapshotRestorePermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName @(<TargetVMName1>) `
            -DiskResourceGroups @(<AttachedDiskResourceGroupsName1>,<TargetDiskResourceGroupsName2>) `
            -SnapshotResourceGroup <SnapshotResourceGroupName>
```

If you are using user-assigned identity for the target VM, use the following script to give the required roles to the target virtual machine user identity, before triggering the snapshot restore.

```powershell
.\SetWorkloadSnapshotRestorePermissions.ps1 -Subscription <SubscriptionId> `
            -VirtualMachineResourceGroup <VMResourceGroup> `
            -VirtualMachineName @(<TargetVMName1>) `
            -DiskResourceGroups @(<AttachedDiskResourceGroupsName1>,<TargetDiskResourceGroupsName2>) `
            -SnapshotResourceGroup <SnapshotResourceGroupName> `
            -UserAssignedServiceIdentityId <UserIdentityPrincipalARMId>
```

Run the following to get more help on the parameters
```powershell
Get-Help SetWorkloadSnapshotRestorePermissions.ps1
```
