import os
from helpers import *

#Enabling colors in the command prompt
os.system("color")

print(bcolors.OKBLUE + "This script will assign the required roles to the principal Id on a particular scope within resource group." + bcolors.ENDC)

#Taking inputs
PrincipalId = input("Please input the PrincipalId of the identity: ")
ResourceGroup = input("Please input the resource group name: ")
Scope = input("Please input the scope: ")
RoleName = input("Please input the role name: ")

assignRoleOnScope(PrincipalId, RoleName, Scope)