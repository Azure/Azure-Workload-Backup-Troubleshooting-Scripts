import os
import fileinput
import sys
import argparse
from helpers import *

#Enabling colors in the command prompt
os.system("color")

desc = bcolors.OKBLUE + "This script will assign the required roles for the source virtual machine on the respective resource groups for workload snapshot backups. \n \n Assigns Disk Backup Reader on the resource group which has virtual machine disks. \n Assigns Disk Snapshot Contributor on the resource group where workload snapshots will be created." + bcolors.ENDC

parser = argparse.ArgumentParser(description=desc)
parser.add_argument("--service-principal-id", "-u", help="Service principal id for user assigned service principal")

requiredNamed = parser.add_argument_group('required arguments')
requiredNamed.add_argument("--subscription", "-s", help="Subscription Id for the virtual machine containing workload", required=True)
requiredNamed.add_argument("--vm-resource-group", "-v", help="Resource group for the virtual machine containing workload", required=True)
requiredNamed.add_argument("--vm-name", "-m", help="Virtual machine name containing workload", required=True)
requiredNamed.add_argument("--disk-resource-groups", "-d", nargs='+', help="Resource group which contains the data disks", required=True)
requiredNamed.add_argument("--snapshot-resource-group", "-n", help="Target resource group for disk snapshots", required=True)

args = parser.parse_args()
subscription = args.subscription
vm_resource_group = args.vm_resource_group
vm_name = args.vm_name
disk_resource_groups = args.disk_resource_groups
snapshot_resource_group = args.snapshot_resource_group

output = os.system("az login -o tsv --only-show-errors > login.txt")
output = os.system("az account set -s {} -o tsv --only-show-errors > context.txt".format(subscription))

if output == 0:
    print(bcolors.OKGREEN + "Successfully logged in to subscription " + subscription + "." + bcolors.ENDC)
    pass
else:
    print(bcolors.FAIL + "Script failed with unexpected error ... " + bcolors.ENDC)
    sys.exit()

if (args.service_principal_id is not None) and (args.service_principal_id != ""):
    service_principal_id = args.service_principal_id
else:
    output = os.system("az vm identity show -n {} -g {} --subscription {} -o tsv --only-show-errors > identityShow.txt".format(vm_name, vm_resource_group, subscription)) 

    print(bcolors.OKGREEN + "Successfully listed VM identity ... " + bcolors.ENDC)
    identity = [line[:-1] for line in fileinput.input(files='identityShow.txt')]

    if len(identity) == 0:
        output = os.system("az vm identity assign -n {} -g {} --subscription {} -o tsv --only-show-errors > identityAssign.txt".format(vm_name, vm_resource_group, subscription))

        if output != 0:
            print(bcolors.FAIL + "Script failed with unexpected error while assigning VM identity ..." + bcolors.ENDC)
            sys.exit()

        print(bcolors.OKGREEN + "Successfully assigned identity to VM " + vm_name + bcolors.ENDC)

        output = os.system("az vm identity show -n {} -g {} --subscription {} -o tsv --only-show-errors > identityShow.txt".format(vm_name, vm_resource_group, subscription)) 
        identity = [line[:-1] for line in fileinput.input(files='identityShow.txt')]
    
    service_principal_id = identity[0].split("\t")[0]  # (identity[1].split('"'))[3]

print(bcolors.OKGREEN + "Assigning permissions to " + service_principal_id + bcolors.ENDC)

diskBackupReaderRoleName = "Disk Backup Reader"
diskSnapshotContributorRoleName = "Disk Snapshot Contributor"

# Assign permissions for disk resource groups
for disk_resource_group in disk_resource_groups:
    assignRoleOnResourceGroup(service_principal_id, disk_resource_group, diskBackupReaderRoleName)        

# Assign permissions for snapshot resource groups
assignRoleOnResourceGroup(service_principal_id, snapshot_resource_group, diskSnapshotContributorRoleName)        

print(bcolors.OKGREEN + "Script Execution completed" + bcolors.ENDC)