import os
from helpers import *

#Enabling colors in the command prompt
os.system("color")

print(bcolors.OKBLUE + "This script will assign the required roles to the principal Id on the resource group." + bcolors.ENDC)

#Taking inputs
PrincipalId = input("Please input the PrincipalId of the identity: ")
ResourceGroup = input("Please input the resource group name: ")
RoleName = input("Please input the role name: ")

assignRoleOnResourceGroup(PrincipalId, ResourceGroup, RoleName)