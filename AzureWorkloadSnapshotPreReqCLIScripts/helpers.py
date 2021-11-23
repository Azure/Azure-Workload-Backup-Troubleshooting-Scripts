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

import os
import fileinput
import sys
import time

def assignRoleOnResourceGroup(PrincipalId, ResourceGroup, RoleName):
    print(bcolors.OKBLUE + "Fetching assigned role " + RoleName + " for " + PrincipalId + " on resource group " + ResourceGroup + bcolors.ENDC)

    output = os.system("az role assignment list -g {} --assignee {} --role {} -o tsv --only-show-errors > roleGet.txt".format(ResourceGroup, PrincipalId, "\"" + RoleName + "\"")) 

    #Error handling
    if output != 0:
        print(bcolors.FAIL + "Script failed with unexpected error ... " + bcolors.ENDC)
        print(bcolors.FAIL + "Please re-run the script after some time." + bcolors.ENDC)
        sys.exit()

    print(bcolors.OKGREEN + "Role assignment with role  " + RoleName + " for " + PrincipalId + " on resource group " + ResourceGroup + " fetched successfully " + bcolors.ENDC)

    role = [line[:-1] for line in fileinput.input(files='roleGet.txt')]

    if len(role):
        print(bcolors.OKBLUE + "Already assigned " + RoleName + " role on resource group " + ResourceGroup + " to "+ PrincipalId + bcolors.ENDC)
    else:
        print(bcolors.OKBLUE + "Assigning role " + RoleName + " to " + PrincipalId + " on resource group " + ResourceGroup + bcolors.ENDC)
        output = os.system("az role assignment create -g {} --assignee {} --role {} -o tsv --only-show-errors".format(ResourceGroup, PrincipalId, "\"" + RoleName + "\""))

        if output != 0:
            print(bcolors.OKBLUE + "Exception caught while assigning role" + bcolors.ENDC)
            print(bcolors.FAIL + "Please re-run the script after some time." + bcolors.ENDC)
            sys.exit()
        else:
            print(bcolors.OKBLUE + "Assigned " + RoleName + " role on resource group " + ResourceGroup + " to " + PrincipalId + " successfully." + bcolors.ENDC)    

def assignRoleOnScope(PrincipalId, RoleName, Scope):
    print(bcolors.OKBLUE + "Fetching assigned role " + RoleName + " for " + PrincipalId + " on scope " + Scope + bcolors.ENDC)

    output = os.system("az role assignment list --assignee {} --role {} --scope {} -o tsv --only-show-errors > roleGetScope.txt".format( PrincipalId, "\"" + RoleName + "\"", Scope)) 

    #Error handling
    if output != 0:
        print(bcolors.FAIL + "Script failed with unexpected error ... " + bcolors.ENDC)
        print(bcolors.FAIL + "Please re-run the script after some time." + bcolors.ENDC)
        sys.exit()

    print(bcolors.OKGREEN + "Role assignment with role" + RoleName + " for " + PrincipalId + " on scope " + Scope + " fetched successfully " + bcolors.ENDC)

    role = [line[:-1] for line in fileinput.input(files='roleGetScope.txt')]

    if len(role):
        print(bcolors.OKBLUE + "Already assigned " + RoleName + " role on scope " + Scope + " to " + PrincipalId + bcolors.ENDC)
    else:
        print(bcolors.OKBLUE + "Assigning role " + RoleName + " to " + PrincipalId + " on scope " + Scope + bcolors.ENDC)
        output = os.system("az role assignment create --assignee {} --role {} --scope {} -o tsv --only-show-errors".format(PrincipalId, "\"" + RoleName + "\"", Scope))

        if output != 0:
            print(bcolors.FAIL + "Exception caught while assigning role" + bcolors.ENDC)
            print(bcolors.FAIL + "Please re-run the script after some time." + bcolors.ENDC)
            sys.exit()
        else:
            print(bcolors.OKBLUE + "Assigned " + RoleName + " role on scope " + Scope + " to " + PrincipalId + " successfully." + bcolors.ENDC)

def assignIdentityToVMs(UserAssignedServiceIdentityId, VirtualMachineResourceGroup, VirtualMachineNames, Subscription):
    service_principal_id = ""
    principalIds = []

    if UserAssignedServiceIdentityId is not None:             
        output = os.system("az identity show --ids {} -o tsv --only-show-errors > msiPrincipal.txt".format(UserAssignedServiceIdentityId))

        if output != 0:
            print(bcolors.FAIL + "Given user assigned identity is not found or script failed with unexpected error ..." + bcolors.ENDC)
            print(bcolors.FAIL + "Please re-run the script after some time." + bcolors.ENDC)
            sys.exit()

        identity = [line[:-1] for line in fileinput.input(files='msiPrincipal.txt')]
        service_principal_id = identity[0].split('\t')[5]
        
        print(bcolors.OKGREEN + "Using user assigned service identity principal " + service_principal_id + bcolors.ENDC)
        principalIds.append(service_principal_id)

        for virtualMachineName in VirtualMachineNames:            
            identity = "\"" + UserAssignedServiceIdentityId + "\""
            print(bcolors.OKBLUE + "Enabling user assigned identity on virtual machine " + virtualMachineName + bcolors.ENDC) 
            output = os.system("az vm identity assign -n {} -g {} --subscription {} --identities {} -o tsv --only-show-errors > identityAssign.txt".format(virtualMachineName, VirtualMachineResourceGroup, Subscription, identity))
            
            if output != 0:
                print(bcolors.FAIL + "script failed with unexpected error ..." + bcolors.ENDC)
                print(bcolors.FAIL + "Please re-run the script after some time." + bcolors.ENDC)
                sys.exit()

            print(bcolors.OKGREEN + "Enabled user assigned identity on virtual machine " + virtualMachineName + bcolors.ENDC) 

    else:
        
        for virtualMachineName in VirtualMachineNames:

            output = os.system("az vm identity show -n {} -g {} --subscription {} -o tsv --only-show-errors > identityShow.txt".format(virtualMachineName, VirtualMachineResourceGroup, Subscription))

            identity = [line[:-1] for line in fileinput.input(files='identityShow.txt')]

            if len(identity) == 0 or "systemassigned" not in identity[0].lower():
                print(bcolors.OKBLUE + "Enabling system assigned identity on virtual machine " + virtualMachineName + bcolors.ENDC) 

                output = os.system("az vm identity assign -n {} -g {} --subscription {} -o tsv --only-show-errors > identityAssign.txt".format(virtualMachineName, VirtualMachineResourceGroup, Subscription))

                if output != 0:
                    print(bcolors.FAIL + "Script failed with unexpected error while assigning VM identity ..." + bcolors.ENDC)
                    print(bcolors.FAIL + "Please re-run the script after some time." + bcolors.ENDC)
                    sys.exit()

                print(bcolors.OKGREEN + "Successfully assigned system identity to VM " + virtualMachineName + bcolors.ENDC)
                time.sleep(10)
                
                output = os.system("az vm identity show -n {} -g {} --subscription {} -o tsv --only-show-errors > identityShow.txt".format(virtualMachineName, VirtualMachineResourceGroup, Subscription)) 
            else:
                print(bcolors.OKGREEN + "System assigned identity already enabled on virtual machine " + virtualMachineName + bcolors.ENDC) 
            
            identity = [line[:-1] for line in fileinput.input(files='identityShow.txt')]
            service_principal_id = identity[0].split("\t")[0] # (identity[1].split('"'))[3]

            #check - add to the principalIds list 
            principalIds.append(service_principal_id)
    return principalIds

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