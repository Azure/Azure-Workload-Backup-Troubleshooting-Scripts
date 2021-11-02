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

function AssignIdentityToVMs
{
    <#
    .SYNOPSIS
        Assigns the given identity to VMs in VM list or enables system assigned identities on VMs
        
    .DESCRIPTION
        Assigns the given identity to VMs in VM list or enables system assigned identities on VMs

    .PARAMETER UserAssignedServiceIdentityId
        ARMId of the UserAssignedServiceIdentity
        /subscriptions/{subscriptonId}/resourceGroups/{resource-group}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{identityName}

    .PARAMETER VirtualMachineResourceGroup
        Virtual machine resource group

    .PARAMETER VirtualMachineNames
        List of virtual machine names      

    .EXAMPLE
        C:\PS> AssignIdentityToVMs -UserAssignedServiceIdentityId <UserAssignedServiceIdentityId> -VirtualMachineResourceGroup <ResourceGroupName> -VirtualMachineNames @(<VM1>, <VM2>, <VM3>)
        C:\PS> AssignIdentityToVMs -UserAssignedServiceIdentityId <UserAssignedServiceIdentityId> -VirtualMachineResourceGroup <ResourceGroupName> -VirtualMachineNames @(<VM1>, <VM2>, <VM3>)

    .NOTES
        Author: Shashwat Trivedi (shtriv@microsoft.com)
    #>

    param(
        [Parameter(Position=0, Mandatory=$false)]
        [string]
        $UserAssignedServiceIdentityId,

        [Parameter(Position=1, Mandatory=$true)]
        [string]
        $VirtualMachineResourceGroup,

        [Parameter(Position=2, Mandatory=$true)]
        [string[]]
        $VirtualMachineNames)

    
    $principalIds = @()

    if ( [string]::IsNullOrEmpty($UserAssignedServiceIdentityId) -eq $false)
    {
        $IdentityName = $UserAssignedServiceIdentityId.Substring($UserAssignedServiceIdentityId.LastIndexOf("/")+1)
        $principalId = (Get-AzADServicePrincipal -DisplayName $IdentityName).Id

        Write-Verbose "Using user assigned service identity $principalId"
        $principalIds = $principalIds + $principalId
    
        # Assign all the VMs the given identity
        foreach ($VirtualMachineName in $VirtualMachineNames)
        {
            $vm = Get-AzVM -ResourceGroupName "$VirtualMachineResourceGroup" -Name "$VirtualMachineName"
            $IdentityList = $vm.Identity.UserAssignedIdentities.Keys
            $IdentityList = $IdentityList + $UserAssignedServiceIdentityId

            Write-Host "Enabling user assigned identity on virtual machine $VirtualMachineName" -ForegroundColor Blue
            $discard = Update-AzVM -ResourceGroupName "$VirtualMachineResourceGroup" -VM $vm -IdentityType UserAssigned -IdentityID $IdentityList
    
            Write-Host "Enabled user assigned identity on virtual machine $VirtualMachineName" -ForegroundColor Green
        }
    }
    else
    {
        # Assign all the VMs the given identity
        foreach ($VirtualMachineName in $VirtualMachineNames)
        {
            $vm = Get-AzVM -ResourceGroupName "$VirtualMachineResourceGroup" -Name "$VirtualMachineName"
    
            if ( [string]::IsNullOrEmpty($vm.Identity.PrincipalId) -eq $false)
            {
                Write-Verbose "System assigned identity enabled on virtual machine $VirtualMachineName"
                $principalIds = $principalIds + $vm.Identity.PrincipalId
            }
            else
            {
                Write-Host "Enabling system assigned identity on virtual machine $VirtualMachineName" -ForegroundColor Blue
    
                $discard = Update-AzVM -ResourceGroupName "$VirtualMachineResourceGroup" -VM $vm -IdentityType SystemAssigned
                Start-Sleep 10
    
                $vm = Get-AzVM -ResourceGroupName "$VirtualMachineResourceGroup" -Name "$VirtualMachineName"
    
                Write-Host "Enabled system assigned identity on virtual machine $VirtualMachineName" -ForegroundColor Green
    
                $principalIds = $principalIds + $vm.Identity.PrincipalId
            }
        }
    }

    return $principalIds
}
