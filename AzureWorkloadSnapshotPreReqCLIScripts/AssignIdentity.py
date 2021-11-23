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
import argparse
from helpers import *

#Enabling colors in the command prompt
os.system("color")

desc = bcolors.OKBLUE + "This script will assign the given identity to VMs in VM list or enables system assigned identities on VMs" + bcolors.ENDC

parser = argparse.ArgumentParser(description=desc)
# parser.add_argument("--service-principal-id", "-u", help="Service principal id for user assigned service principal")
parser.add_argument("--user-assigned-service-identity-id", "-u", help="ARMId of the UserAssignedServiceIdentity \n \n /subscriptions/{subscripton-id}/resourceGroups/{resource-group}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{identity-name}")

requiredNamed = parser.add_argument_group('required arguments')
requiredNamed.add_argument("--virtual-machine-resource-group", "-v", help=" Virtual machine resource group", required=True)
requiredNamed.add_argument("--virtual-machine-names", "-m", nargs='+', help="List of virtual machine names", required=True)
requiredNamed.add_argument("--subscription", "-s", help="Subscription Id for the virtual machine containing workload", required=True)

args = parser.parse_args()
UserAssignedServiceIdentityId = args.user_assigned_service_identity_id
VirtualMachineResourceGroup = args.virtual_machine_resource_group
VirtualMachineNames = args.virtual_machine_names
subscription = args.subscription # UserAssignedServiceIdentityId.split("/")[2]

assignIdentityToVMs(UserAssignedServiceIdentityId, VirtualMachineResourceGroup, VirtualMachineNames, subscription)