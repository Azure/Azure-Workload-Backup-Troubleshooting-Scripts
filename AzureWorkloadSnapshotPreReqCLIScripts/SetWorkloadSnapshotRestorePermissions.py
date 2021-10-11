def assignRoleOnResourceGroup(PrincipalId, ResourceGroup, RoleName):
    output = os.system("az role assignment list -g {} --assignee {} --role {} -o tsv --only-show-errors > roleGet.txt".format(ResourceGroup, PrincipalId, RoleName)) 

    #Error handling
    if output != 0:
        print(bcolors.FAIL + "Script failed with unexpected error  " + bcolors.ENDC)
        sys.exit()

    print(bcolors.OKGREEN + "Role Assignment fetched   " + bcolors.ENDC)

    role = [line[:-1] for line in fileinput.input(files='roleGet.txt')]

    if len(role):
        print(bcolors.OKBLUE + "Already assigned " + RoleName + " role on resource group " + ResourceGroup + " to "+ PrincipalId + bcolors.ENDC)
    else:
        print(bcolors.OKBLUE + "Assigning role " + RoleName + " to " + PrincipalId + " on resource group " + ResourceGroup + bcolors.ENDC)
        output = os.system("az role assignment create -g {} --assignee {} --role {} -o tsv --only-show-errors".format(ResourceGroup, PrincipalId, RoleName))

        if output != 0:
            print(bcolors.OKBLUE + "Exception caught while assigning role" + bcolors.ENDC)
            sys.exit()
        else:
            print(bcolors.OKBLUE + "Assigned " + RoleName + " role on resource group " + ResourceGroup + " to " + PrincipalId + "successfully." + bcolors.ENDC)    

def assignRoleOnScope(PrincipalId, ResourceGroup, RoleName, Scope):
    output = os.system("az role assignment list -g {} --assignee {} --role {} --scope {} -o tsv --only-show-errors > roleGetScope.txt".format(ResourceGroup, PrincipalId, RoleName, Scope)) 

    #Error handling
    if output != 0:
        print(bcolors.FAIL + "Script failed with unexpected error ... " + bcolors.ENDC)
        sys.exit()

    print(bcolors.OKGREEN + "Role Assignment fetched..." + bcolors.ENDC)

    role = [line[:-1] for line in fileinput.input(files='roleGetScope.txt')]

    if len(role):
        print(bcolors.OKBLUE + "Already assigned " + RoleName + " role on scope " + Scope + " in resource group " + ResourceGroup + " to "+ PrincipalId + bcolors.ENDC)
    else:
        print(bcolors.OKBLUE + "Assigning role " + RoleName + " to " + PrincipalId + " on scope " + Scope + " in resource group " + ResourceGroup + bcolors.ENDC)
        output = os.system("az role assignment create -g {} --assignee {} --role {} --scope {} -o tsv --only-show-errors".format(ResourceGroup, PrincipalId, RoleName, Scope))

        if output != 0:
            print(bcolors.OKBLUE + "Exception caught while assigning role" + bcolors.ENDC)
            sys.exit()
        else:
            print(bcolors.OKBLUE + "Assigned " + RoleName + " role on scope " + Scope + " in resource group " + ResourceGroup + " to " + PrincipalId + "successfully." + bcolors.ENDC)

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

import os
import fileinput
import sys
import argparse

#Enabling colors in the command prompt
os.system("color")

desc = bcolors.OKBLUE + "This script will assign the required roles for the source virtual machine on the respective resource groups for workload snapshot backups. \n \n Assigns Disk Backup Reader on the resource group which has virtual machine disks. \n Assigns Disk Snapshot Contributor on the resource group where workload snapshots will be created." + bcolors.ENDC

parser = argparse.ArgumentParser(description=desc)
parser.add_argument("--service-principal-id", "-u", help="Service principal id for user assigned service principal")

requiredNamed = parser.add_argument_group('required arguments')
requiredNamed.add_argument("--subscription", "-s", help="Subscription Id for the virtual machine containing workload", required=True)
requiredNamed.add_argument("--vm-resource-group", "-v", help="Resource group for the virtual machine containing workload", required=True)
requiredNamed.add_argument("--vm-name", "-m", help="Virtual machine name containing workload", required=True)
requiredNamed.add_argument("--disk-resource-groups", "-d", nargs='+', help="Resource group which contains the exisiting data disks or where new data disks are created", required=True)
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
    identity = [line[:-1] for line in fileinput.input(files='identityShow.txt')]

    if len(identity) == 0:
        output = os.system("az vm identity assign -n {} -g {} --subscription {} -o tsv --only-show-errors > identityAssign.txt".format(vm_name, vm_resource_group, subscription))
        output = os.system("az vm identity show -n {} -g {} --subscription {} -o tsv --only-show-errors > identityShow.txt".format(vm_name, vm_resource_group, subscription)) 
        identity = [line[:-1] for line in fileinput.input(files='identityShow.txt')]
    
    service_principal_id = (identity[1].split('"'))[3]

print(bcolors.OKGREEN + "Assigning permissions to " + service_principal_id + bcolors.ENDC)

diskSnapshotContributorRoleName = "Disk Snapshot Contributor"
vmContributorRoleName = "Virtual Machine Contributor"
diskRestoreOperatorRoleName = "Disk Restore operator"

# Assign permissions for disk resource groups
for disk_resource_group in disk_resource_groups:
    assignRoleOnResourceGroup(service_principal_id, disk_resource_group, diskRestoreOperatorRoleName)        

# Assign permissions for snapshot resource groups
assignRoleOnResourceGroup(service_principal_id, snapshot_resource_group, diskSnapshotContributorRoleName)        

# Assign permission on virtual machine
output = os.system("az vm show -n {} -g {} --subscription {} --query id  -o tsv --only-show-errors > vmId.txt".format(vm_name, vm_resource_group, subscription))
vm_id = [line[:-1] for line in fileinput.input(files='vmId.txt')][0][1:-1]

assignRoleOnScope(service_principal_id, vm_resource_group, vmContributorRoleName, vm_id)

print(bcolors.OKGREEN + "Script Execution completed" + bcolors.ENDC)