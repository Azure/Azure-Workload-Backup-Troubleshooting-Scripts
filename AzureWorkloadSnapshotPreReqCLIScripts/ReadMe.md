# Azure Workoad Snapshot Pre-Req Scripts for CLI

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
|Snapshot RG where the snapshots would be restored   |Disk snapshot contributor  |
|Target Disk RG where all disks will be created during restore  |Disk Restore operator   |
|Source Disk RG (RG where all existing disks of target VM are present)   |Disk Restore operator   |
|Target VM     |Virtual Machine Contributor    |

+ For Snapshot deletion after retention period

Azure Backup Management Service requires the following roles

Resource (Access control)  |Role
------ | ------
|Snapshot RG where the snapshots would be restored   |Disk snapshot contributor  |

## Requirements

Az CLI module is required to be installed on your machine before running the python scripts provided. To know more about Az CLI click [here](https://github.com/Azure/azure-cli/)

## Usage 

### Backup
Before the snapshot backup, use the following script to give the required roles to the virtual machine system identity

```cmd
python SetWorkloadSnapshotBackupPermissions.py --subscription <SubscriptionId> --vm-resource-group <VMResourceGroup> --vm-name  <SourceWorkloadVMName> --disk-resource-groups DiskResourceGroupsName> <DiskResourceGroupsName> --snapshot-resource-group <SnapshotResourceGroupName>
```

Before the snapshot backup, use the following script to give the required roles to the user identity

```cmd
python SetWorkloadSnapshotBackupPermissions.py  --subscription <SubscriptionId> --vm-resource-group <VMResourceGroup> --vm-name  <SourceWorkloadVMName> --disk-resource-groups <DiskResourceGroupsName> <DiskResourceGroupsName> --snapshot-resource-group <SnapshotResourceGroupName> --service-principal-id <UserIdentityPrincipalId>
```

Run the following to get more help on the parameters
```cmd
python SetWorkloadSnapshotBackupPermissions.py --help
```

### Restore

Before the snapshot disk restore, use the following script to give the required roles to the virtual machine system identity

```cmd
python SetWorkloadSnapshotRestorePermissions.py --subscription <SubscriptionId> --vm-resource-group <VMResourceGroup> --vm-name <SourceWorkloadVMName> --disk-resource-groups <DiskResourceGroupsName> <DiskResourceGroupsName> --snapshot-resource-group <SnapshotResourceGroupName> 
```

Before the snapshot backup, use the following script to give the required roles to the user identity

```cmd
python SetWorkloadSnapshotRestorePermissions.py ---subscription <SubscriptionId> --vm-resource-group <VMResourceGroup> --vm-name <SourceWorkloadVMName> --disk-resource-groups DiskResourceGroupsName> <DiskResourceGroupsName> --snapshot-resource-group <SnapshotResourceGroupName> --service-principal-id <UserIdentityPrincipalId>
```

Run the following to get more help on the parameters
```cmd
python SetWorkloadSnapshotRestorePermissions.py --help
```
