import os
import fileinput
import sys

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

#Enabling colors in the command prompt
os.system("color")

print(bcolors.OKBLUE + "This script will assign the required roles to the principal Id on the resource group." + bcolors.ENDC)

#Taking inputs
PrincipalId = input("Please input the PrincipalId of the identity: ")
ResourceGroup = input("Please input the resource group name: ")
RoleName = input("Please input the role name: ")

print(bcolors.OKBLUE + "Fetching assigned role " + RoleName + " for " + PrincipalId + " on resource group " + ResourceGroup + bcolors.ENDC)

# get role assignments 
output = os.system("az role assignment list -g {} --assignee {} --role {} -o tsv --only-show-errors > roleGet.txt".format(ResourceGroup, PrincipalId, RoleName)) 

#Error handling
if output != 0:
    print(bcolors.FAIL + "Script failed with unexpected error ... " + bcolors.ENDC)
    sys.exit()

print(bcolors.OKGREEN + "Fetched role " + RoleName + " assigned to " + PrincipalId + " on resource group " + ResourceGroup + bcolors.ENDC)

role = [line[:-1] for line in fileinput.input(files='roleGet.txt')]

if len(role):
    print(bcolors.OKBLUE + "Already assigned " + RoleName + " role on resource group " + ResourceGroup + " to "+ PrincipalId + bcolors.ENDC)
else:
    print(bcolors.OKBLUE + "Assigning role " + RoleName + " to " + PrincipalId + " on resource group " + ResourceGroup + bcolors.ENDC)
    output = os.system("az role assignment create -g {} --assignee {} --role {} -o tsv --only-show-errors".format(ResourceGroup, PrincipalId, RoleName))

    if output != 0:
        print(bcolors.FAIL + "Exception caught while assigning role" + bcolors.ENDC)
        sys.exit()
    else:
        print(bcolors.OKBLUE + "Assigned " + RoleName + " role on resource group " + ResourceGroup + " to " + PrincipalId + "successfully." + bcolors.ENDC)