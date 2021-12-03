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

function AssignRoleOnResourceGroup
{
    <#
    .SYNOPSIS
        Assign the required roles to the principal Id on the resource group
        
    .DESCRIPTION
        Assign the required roles to the principal Id on the resource group

    .PARAMETER PrincipalId
        PrincipalId on the identity

    .PARAMETER ResourceGroup
        Resource group

    .EXAMPLE
        C:\PS> AssignRoleOnResourceGroup -PrincipalId <PrincipalId> -ResourceGroup <ResourceGroupName> -RoleName <RoleDefinitionName>

    .NOTES
        Author: Shashwat Trivedi (shtriv@microsoft.com)
    #>

    param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]
        $PrincipalId,

        [Parameter(Position=1, Mandatory=$true)]
        [string]
        $ResourceGroup,

        [Parameter(Position=2, Mandatory=$true)]
        [string]
        $RoleName)

    
    Write-Verbose "Fetching assigned role $RoleName for $PrincipalId on resource group $ResourceGroup"

    $role= Get-AzRoleAssignment `
        -ObjectId $PrincipalId `
        -RoleDefinitionName $RoleName `
        -ResourceGroupName $ResourceGroup `
        -ErrorAction "Ignore"

    if($role -eq $null)
    {
        try
        {
            Write-Host "Assigning role $RoleName to $PrincipalId on resource group $ResourceGroup" -ForegroundColor Blue

            New-AzRoleAssignment `
                -ObjectId $PrincipalId `
                -RoleDefinitionName $RoleName `
                -ResourceGroupName $ResourceGroup
        }
        catch
        {
            Write-Error "Exception caught while assigning role" -ForegroundColor Red
            Write-Error $Error[0].Exception -ForegroundColor Red
        }
    }
    else
    {
        Write-Host("Already assigned $RoleName role on resource group $ResourceGroup to $PrincipalId" ) -ForegroundColor Green
    }
}

function AssignRoleOnResource
{
    <#
    .SYNOPSIS
        Assign the required roles to the principal Id on the resource group
        
    .DESCRIPTION
        Assign the required roles to the principal Id on the resource group

    .PARAMETER PrincipalId
        PrincipalId on the identity

    .PARAMETER ResourceGroup
        Resource group

    .PARAMETER ResourceName
        Resource name

    .PARAMETER ResourceType
        Resource type like Microsoft.Compute/virtualMachine        

    .EXAMPLE
        C:\PS> AssignRoleOnResourceGroup -PrincipalId <PrincipalId> `
                -ResourceGroup <ResourceGroupName> `
                -ResourceName <ResourceName> `
                -ResourceType <ResourceType> ` 
                -RoleName <RoleDefinitionName>

    .NOTES
        Author: Shashwat Trivedi (shtriv@microsoft.com)
    #>

    param(
        [Parameter(Position=0, Mandatory=$true)]
        [string]
        $PrincipalId,

        [Parameter(Position=1, Mandatory=$true)]
        [string]
        $ResourceGroup,

        [Parameter(Position=2, Mandatory=$true)]
        [string]
        $ResourceName,

        [Parameter(Position=3, Mandatory=$true)]
        [string]
        $ResourceType,

        [Parameter(Position=4, Mandatory=$true)]
        [string]
        $RoleName)

    
    Write-Verbose "Fetching assigned role $RoleName for $PrincipalId on $ResourceName in $ResourceGroup"

    $role= Get-AzRoleAssignment `
        -ObjectId $PrincipalId `
        -RoleDefinitionName $RoleName `
        -ResourceGroupName $ResourceGroup `
        -ResourceName $ResourceName `
        -ResourceType $ResourceType

    if($role -eq $null)
    {
        try
        {
            Write-Host "Assigning role $RoleName to $PrincipalId on $ResourceName in $ResourceGroup" -ForegroundColor Blue

            New-AzRoleAssignment `
                -ObjectId $PrincipalId `
                -RoleDefinitionName $RoleName `
                -ResourceGroupName $ResourceGroup `
                -ResourceName $ResourceName `
                -ResourceType $ResourceType
        }
        catch
        {
            Write-Error "Exception caught while assigning role" -ForegroundColor Red
            Write-Error $Error[0].Exception -ForegroundColor Red
        }
    }
    else
    {
        Write-Host("Already assigned $RoleName role on $ResourceName in $ResourceGroup to $PrincipalId" )  -ForegroundColor Green
    }
}