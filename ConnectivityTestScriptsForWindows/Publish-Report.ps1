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

<#  
.SYNOPSIS  
    Prepares report html from connectivity stats obtained via RunConnectivityTests.ps1.
.DESCRIPTION  
    Prepares report html from connectivity stats obtained via RunConnectivityTests.ps1.
.PARAMETER ReportXmlFile
    Xml output file updated by RunConnectivityTests.ps1
.PARAMETER ReportHtmlFile
    Output html file
.PARAMETER IsPrivateEndpointEnabled
    Specifies if the workload is protected with Recovery Services Vault with private endpoint
#>

Param(
    [parameter(position=0,Mandatory=$true)]
    $ReportXmlFile,

    [parameter(position=1,Mandatory=$true)]
    $ReportHtmlFile,

    [switch]$IsPrivateEndpointEnabled
)

#Recommedations
###########################################################################
$AADCommonIssue = 
"
<div style='background-color:#FF033E;color:white;padding:20px;'>
<h2>Azure Active Directory (AAD) Common Issue</h2>
<ul>
<li> Check DNS resolution for Azure active directory FQDN 
<ul>
    <li>login.microsoftonline.com (Azure AD Global service)</li>
    <li>login.microsoftonline.us (Azure AD for US Government)</li>
    <li>login.partner.microsoftonline.cn (Azure AD China)</li>
</ul>
</br>
Run 
</br>
Resolve-DnsName login.microsoftonline.com
</br> (or equivalent FQDN for the Azure environment in powershell) on the machine and verify if the uri resolution goes through.</li>
<li> Check the Network Security Group (NSG) attached to virtual machine's subnet, NSG should allow outbound connection to 'AzureActiveDirectory' <a href = 'https://docs.microsoft.com/azure/virtual-network/service-tags-overview'>Service Tags</a>
</br>
Network Security Groups for a virtual machine can be checked at Azure portal Virtual machine blade -> Networking Settings -> Network Interface -> Outbound port rules. <IMG SRC='media/VMNetworkblade.png' ALT='Virtual machine NSG outbound port rules' width=1024 height=480/>
</br>
If the rule is missing, click on 'Add outbound port rule' and fill in the Source as Virtual network, Destination as Service tag and Destination service tag as 'AzureActiveDirectory'. Set Action as Allow and click Add.
Specific ports for this connection can be found under sections 56 and 59 in <a href='https://docs.microsoft.com/microsoft-365/enterprise/urls-and-ip-address-ranges?view=o365-worldwide&preserve-view=true#microsoft-365-common-and-office-online'> Microsoft 365 Common and Office Online.</a>
</br>
<img src='media/AddOutboundRuleAAD.png' alt='Add outbound port rule blade for Azure active directory' height=480 width=256/>
</li>
Check your firewall settings for outbound connection to URLs mentioned under sections 56 and 59 in <a href='https://docs.microsoft.com/microsoft-365/enterprise/urls-and-ip-address-ranges?view=o365-worldwide&preserve-view=true#microsoft-365-common-and-office-online'> Microsoft 365 Common and Office Online.</a> </li>
</ul>
</div>
"

$AzureBackupCommonIssue = 
"
<div style='background-color:#FF033E;color:white;padding:20px;'>
<h2>Azure Backup Common Issue</h2>
<ul>
<li> <b>Azure Workload Backup doesn't support authenticated Proxy servers. <a href ='https://docs.microsoft.com/azure/backup/backup-sql-server-database-azure-vms#use-an-http-proxy-server-to-route-traffic'> Use an HTTP proxy server to route traffic</a> </b></li>
<li> Azure Workload Backup only supports TLS 1.2. Change TLS registry settings as described <a href = 'https://docs.microsoft.com/windows-server/security/tls/tls-registry-settings'>here</a> to enable TLS 1.2.</li>
<li> If not using Private Endpoint, check the Network Security Group (NSG) attached to subnet, NSG should allow outbound connection to 'AzureBackup' <a href = 'https://docs.microsoft.com/azure/virtual-network/service-tags-overview'>Service Tags.</a>
</br>
Network Security Groups for a virtual machine can be checked at Azure portal Virtual machine blade -> Networking Settings -> Network Interface -> Outbound port rules. <IMG SRC='media/VMNetworkblade.png' ALT='Virtual machine NSG outbound port rules' width=1024 height=480/>
</br>
If the rule is missing, click on 'Add outbound port rule' and fill in the Source as Virtual network, Destination as Service tag and Destination service tag as 'AzureBackup'. Set Action as Allow and click Add.
Specific ports for this connection can be found in <a href='https://docs.microsoft.com/azure/backup/backup-sql-server-database-azure-vms#allow-access-to-service-fqdns'> this section</a>
</br>
<img src='media/AddOutboundRuleBackup.png' alt='Add outbound port rule blade for Azure backup' height=480 width=256/>
</br>
Check your firewall settings for outbound connection to URLs mentioned in <a href='https://docs.microsoft.com/azure/backup/backup-sql-server-database-azure-vms#allow-access-to-service-fqdns'> this section</a></li>
<li> If the connection status for service contains 'The remote name could not be resolved', ensure that the DNS is configured properly to resolve the required URLs. If you are using private endpoint, guidance for DNS management is documented <a href ='https://docs.microsoft.com/azure/backup/private-endpoints#manage-dns-records'>here</a></li>
</ul>
</div>
"

$PrivateEndpointCommonIssue = 
"
<div style='background-color:#FF033E;color:white;padding:20px;'>
<h2>Azure Backup Private Endpoint Common Issue</h2>
<li> Azure workload Backup requires the DNS resolution for Azure Backup service URLs to Private IP for trafficing the network on Azure backbone. Documentation for <a href= 'https://docs.microsoft.com/azure/backup/private-endpoints#manage-dns-records'> DNS Management.</a>
If you are using Azure Private DNS zone, ensure that the Private DNS zones are linked to the VNET. You can more information on private dns zone VNET link <a href= 'https://docs.microsoft.com/azure/dns/private-dns-virtual-network-links'> here.</a>
<table>
    <tr>
        <th>Private DNS Zone</th>
        <th>Cloud</th>        
    </tr>
    <tr>
        <td>privatelink.< geo > .backup.windowsazure.com <br>
            privatelink.blob.core.windows.net <br>
            privatelink.queue.core.windows.net</td>
            <td>Public</td>
    </tr>
    <tr>
        <td>privatelink.< geo >.backup.windowsazure.cn<br>
            privatelink.blob.core.chinacloudapi.cn <br>
            privatelink.queue.core.chinacloudapi.cn</td>
            <td>China</td>
    </tr>
    <tr>
        <td>privatelink.< geo >.backup.windowsazure.us<br>
            privatelink.blob.core.usgovcloudapi.net <br>
            privatelink.queue.core.usgovcloudapi.net</td>
            <td>US Gov</td>
    </tr>        
</table>
If you are using Custom DNS, ensure you have added the required DNS entries. You can check the DNS entries in the DNS configuration tab for Private endpoint created for Recovery Services Vault.
</br>
<img src='media/PEDNSConfig.png' alt='DNS configuration for the private endpoint' width=1024 height=640/>
</br>
</li>
<li> If you are using a private DNS zone which is in a subscription different from the RS vault's subscription, follow the guidance <a href= 'https://docs.microsoft.comazure/backup/private-endpoints#create-dns-entries-when-the-dns-serverdns-zone-is-present-in-another-subscription'>here</a></li>
<li> If you are using a proxy server, you can bypass the domains mentioned <a href ='https://docs.microsoft.com/azure/backup/private-endpoints-overview#difference-in-network-connections-due-to-private-endpoints'>here</a>, this is needed for workload extension to traffic network to private IP directly.</li>
</div>
"

$AzureStorageCommonIssue =
"
<div style='background-color:#FF033E;color:white;padding:20px;'>
<h2>Azure Storage Common Issue</h2>
<ul>
<li> Check the Network Security Group (NSG) attached to virtual machine's subnet, NSG should allow outbound connection to 'Storage' <a href = 'https://docs.microsoft.com/azure/virtual-network/service-tags-overview'>Service Tags</a>
</br>
Network Security Groups for a virtual machine can be checked at Azure portal Virtual machine blade -> Networking Settings -> Network Interface -> Outbound port rules. <IMG SRC='media/VMNetworkblade.png' ALT='Virtual machine NSG outbound port rules' width=1024 height=480/>
</br>
If the rule is missing, click on 'Add outbound port rule' and fill in the Source as Virtual network, Destination as Service tag and Destination service tag as 'Storage'. Set Action as Allow and click Add.
Specific ports for this connection can be found in <a href='https://docs.microsoft.com/azure/backup/backup-sql-server-database-azure-vms#allow-access-to-service-fqdns'> this section</a>
</br>
<img src='media/AddOutboundRuleStorage.png' alt='Add outbound port rule blade for Azure storage' height=480 width=256/>
</br>
Check your firewall settings for outbound connection to URLs mentioned in <a href='https://docs.microsoft.com/azure/backup/backup-sql-server-database-azure-vms#allow-access-to-service-fqdns'> this section</a> </li>
</ul>
</div>
"

$report = [xml] (Get-Content "$ReportXmlFile")

# Setting AAD Connectivity Report 
#########################################################################
$aadConnecivityReport = "<p>Status : <span style=""color:$($report.report.ConnectivityTests.AAD.Status);"">$($report.report.ConnectivityTests.AAD.Status)</span>
<br>
<span style=""color:Red;""> $($report.report.ConnectivityTests.AAD.Exception) </span>
</p>"

if ($($report.report.ConnectivityTests.AAD.Status) -eq "Red")
{
    $aadConnecivityReport += $AADCommonIssue
}

# Setting Backup Services Connectivity Report 
#########################################################################
$azureBackupStatus = $true
$backupConnectivityReport = "<table style=""width:100%"">
<tbody>
    <tr>
        <th>TLS</th>
        <th>TLS11</th>
        <th>TLS12</th>
    </tr>
"
$body = ""

foreach( $serviceStatus in $report.report.ConnectivityTests.Services.Service)
{
    $body += "
    <tr>
        <th style=""text-align:center;"" colspan=""3"">$($serviceStatus.Name)</th>

    </tr>
    <tr>
        <td width=""(100/3)%"" >$($serviceStatus.TLS)</td>
        <td width=""(100/3)%"">$($serviceStatus.TLS11)</td>
        <td width=""(100/3)%"">$($serviceStatus.TLS12)</td>
    </tr>"

    if ((-not (($($serviceStatus.TLS) -eq "Green" )-or 
        ($($serviceStatus.TLS11) -eq "Green" ) -or 
        ($($serviceStatus.TLS12) -eq "Green"))) -and 
	($($serviceStatus.Name) -ne ""))
    {
        $azureBackupStatus = $false
    }
}

$backupConnectivityReport += $body +
"</tbody>
</table>"

if (-not ($azureBackupStatus -eq $true))
{
    $backupConnectivityReport += $AzureBackupCommonIssue
}


# Setting Storage Connectivity Report 
#########################################################################
$storageConnectivityReport = "<table style=""width:100%"">
<tbody>
    <tr>
        <th>TLS</th>
        <th>TLS11</th>
        <th>TLS12</th>
    </tr>
    <tr>
        <td width=""(100/3)%"">$($report.report.ConnectivityTests.Storage.TLS)</td>
        <td width=""(100/3)%"">$($report.report.ConnectivityTests.Storage.TLS11)</td>
        <td width=""(100/3)%"">$($report.report.ConnectivityTests.Storage.TLS12)</td>
    </tr>
</tbody>
</table>"

if (-not ( ($($report.report.ConnectivityTests.Storage.TLS) -eq "Green") -or
    ($($report.report.ConnectivityTests.Storage.TLS11) -eq "Green") -or 
    ($($report.report.ConnectivityTests.Storage.TLS12) -eq "Green")))
{
    $storageConnectivityReport = $AzureStorageCommonIssue
}

# TLS Settings
#########################################################################
$tlsSettings = "<table style=""width:100%"" border=""1"">
<tbody>
    <tr>
        <td width=""(100/2)%"">DefaultSecureProtocols Enabled</td>
        <td width=""(100/2)%"">$($report.report.TLSSettings.DefaultSettings)</td>
    </tr>
    <tr>
        <td width=""(100/2)%"">TLS</td>
        <td width=""(100/2)%"">Enabled for Client : $($report.report.TLSSettings.TLS.Client -ne "0")</td>
    </tr>
    <tr>
        <td width=""(100/2)%"">TLS 1.0</td>
        <td width=""(100/2)%"">Enabled for Client : $($report.report.TLSSettings.TLS11.Client -ne "0")</td>
    </tr>
    <tr>
        <td width=""(100/2)%"">TLS 1.2</td>
        <td width=""(100/2)%"">Enabled for Client : $($report.report.TLSSettings.TLS12.Client -ne "0")</td>
    </tr>        
</tbody>
</table>"

# Setting Private Endpoint Report 
#########################################################################
$dnsReport = "<table style=""width:100%"">
<tbody>
    <tr>
        <th width=""(100/2)%"" >DNS Record</th>
        <th width=""(100/2)%"" >PrivateIp</th>
    </tr>
"
$body = ""

foreach( $dnsResolutionStatus in $report.report.PrivateEndpointTests.DNSResolutions.DNS)
{
    $body += "
    <tr>
        <td width=""(100/2)%"" >$($dnsResolutionStatus.DNSEntry)</td>
        <td width=""(100/2)%"" >$($dnsResolutionStatus.PrivateIp)</td>
    </tr>"
}

$dnsReport += $body +
"</tbody>
</table>"

if ( $IsPrivateEndpointEnabled.IsPresent )
{
    $dnsReport += $PrivateEndpointCommonIssue
}

#Prepare Report
###########################################################################
$html = "
<html>

<body>
    <h1>Azure Workload Backup Connectivity Status</h1>
    <h3 style=""background-color:powderblue; font-family:helvetica;""> Private Endpoint Tests (If configured </h3>
    <div class = ""DNSResolution"">
        <h4 style=""background-color:lightgreen; font-family:helvetica;"">DNS Resolution</h4>
        $dnsReport
    </div>
    <br><br>
        <h3 style=""background-color:powderblue; font-family:helvetica;"">Test Connectivity</h3>
    <div class = ""AADStatus"">
        <h4 style=""background-color:lightgreen; font-family:helvetica;"">Azure Active Directory</h4>
        $aadConnecivityReport
    </div>
    <div class=""BackupServicesConnectivity"">
        <h4 style=""background-color:lightgreen; font-family:helvetica;"">Azure Backup Services</h4>
        $backupConnectivityReport
    </div>
    <div class = ""StorageConnectivity"">
        <h4 style=""background-color:lightgreen; font-family:helvetica;"">Azure Storage Service</h4>
        $storageConnectivityReport
    </div>
    <div class=""BackupServicesConnectivity"">
        <h4 style=""background-color:lightgreen; font-family:helvetica;"">TLS Settings</h4>
        $tlsSettings
    </div>    
    <br><br>
    <h3 style=""background-color:powderblue; font-family:helvetica;"">Proxy Settings</h3>
    <div style='background-color:#007FFF;color:white;padding:20px;'>
    <h3> <b> If Proxy Settings are not common for all users, ensure that the settings for user NT Authority\System and NT Service\AzureWLBackupPluginSvc are same. Run Set-ProxySettingsForPluginUser.ps1 as NT Authority\System user to set the settings for NT Service\AzureWLBackupPluginSvc user same as LocalSystem user.
    You can download the tool <a href='https://docs.microsoft.com/sysinternals/downloads/pstools'>PsExec from here.</a> Extract the zip.</br>
    Run
    </br> 
    PsExec64.exe -s -i powershell  
    </br>
    to start powershell as LocalSystem. Run the script Set-ProxySettingsForPluginUser.ps1 from this shell.
    </b></h3>
    </div>
	$($report.report.ProxySettings)
</body>
</html>
"
$html | Out-File -FilePath $ReportHtmlFile
# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCPQbrD12Yim6cl
# cLFEFfavM4KP8HmPRak2Q9yMHKPxAqCCDYEwggX/MIID56ADAgECAhMzAAACUosz
# qviV8znbAAAAAAJSMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjEwOTAyMTgzMjU5WhcNMjIwOTAxMTgzMjU5WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDQ5M+Ps/X7BNuv5B/0I6uoDwj0NJOo1KrVQqO7ggRXccklyTrWL4xMShjIou2I
# sbYnF67wXzVAq5Om4oe+LfzSDOzjcb6ms00gBo0OQaqwQ1BijyJ7NvDf80I1fW9O
# L76Kt0Wpc2zrGhzcHdb7upPrvxvSNNUvxK3sgw7YTt31410vpEp8yfBEl/hd8ZzA
# v47DCgJ5j1zm295s1RVZHNp6MoiQFVOECm4AwK2l28i+YER1JO4IplTH44uvzX9o
# RnJHaMvWzZEpozPy4jNO2DDqbcNs4zh7AWMhE1PWFVA+CHI/En5nASvCvLmuR/t8
# q4bc8XR8QIZJQSp+2U6m2ldNAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUNZJaEUGL2Guwt7ZOAu4efEYXedEw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDY3NTk3MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAFkk3
# uSxkTEBh1NtAl7BivIEsAWdgX1qZ+EdZMYbQKasY6IhSLXRMxF1B3OKdR9K/kccp
# kvNcGl8D7YyYS4mhCUMBR+VLrg3f8PUj38A9V5aiY2/Jok7WZFOAmjPRNNGnyeg7
# l0lTiThFqE+2aOs6+heegqAdelGgNJKRHLWRuhGKuLIw5lkgx9Ky+QvZrn/Ddi8u
# TIgWKp+MGG8xY6PBvvjgt9jQShlnPrZ3UY8Bvwy6rynhXBaV0V0TTL0gEx7eh/K1
# o8Miaru6s/7FyqOLeUS4vTHh9TgBL5DtxCYurXbSBVtL1Fj44+Od/6cmC9mmvrti
# yG709Y3Rd3YdJj2f3GJq7Y7KdWq0QYhatKhBeg4fxjhg0yut2g6aM1mxjNPrE48z
# 6HWCNGu9gMK5ZudldRw4a45Z06Aoktof0CqOyTErvq0YjoE4Xpa0+87T/PVUXNqf
# 7Y+qSU7+9LtLQuMYR4w3cSPjuNusvLf9gBnch5RqM7kaDtYWDgLyB42EfsxeMqwK
# WwA+TVi0HrWRqfSx2olbE56hJcEkMjOSKz3sRuupFCX3UroyYf52L+2iVTrda8XW
# esPG62Mnn3T8AuLfzeJFuAbfOSERx7IFZO92UPoXE1uEjL5skl1yTZB3MubgOA4F
# 8KoRNhviFAEST+nG8c8uIsbZeb08SeYQMqjVEmkwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVZzCCFWMCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAlKLM6r4lfM52wAAAAACUjAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgL6XQ1cfO
# tQKEVDbxOcwR71XAbyv1HsItiso9TGtecZgwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQB3tGhOCgg2KwqOBLTeKCzrATgf0I9MNPS1BbmtPEmx
# wP8n6V9PE9UwvABynSkjdozk3gqdV2l2gtM+5e6OZn7bTkhvK8sz469oc6thd9Wa
# 3hBd1rlRF0qrX9kSlgRJba/rB3GAGRVzwgB46ijTyCsXZ2WtWhOq8gi5cRUNtScl
# ixdfTP5kz2O212UTyhD5HscDRNhsk/Ts/gWo689EIu2nDHD9uoTkQ7zHeVR6JSH3
# esmJmTqkbhXc6hHn9df4q+BSaOChbO6Xocd9sW5J9/iqSpg3086a63Ny8spgBecy
# vjLXNgX8TFKEVYuPue6epSN3yNlJ7lumf5+gcRcqogyZoYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIOIrTEhxEpH+S427nouqkdCtfvnuI0Oy0dBW19+U
# MWyxAgZhk+/JR9gYEzIwMjExMjAzMDQ0MDU0LjU5N1owBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjpGN0E2LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABWZ/8fl8s6vJDAAAA
# AAFZMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTIxMDExNDE5MDIxNVoXDTIyMDQxMTE5MDIxNVowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGN0E2
# LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK54xGHJZ8SHREtNIoBo
# 9AG6Mro8gEZCt8WgV/mNdIt2tMOP3zVYU4+sRsImxTwfzJEDBWaTc7LxlEy/1302
# fRmd/R2pwnY7pyT90yvZAmQQLZ6D+faGBwwhi5rre/tmBJdbAXFZ8qL2JDc4txBn
# 30Mr1C8DFBdrIjwbP+i2RdAOaSwIs/xQsMeZAz3v5j9VEdwq8+iM6YcLcqKrYAwP
# +OE58371ST5kj2f7quToeTXhSvDczKYrVokL3Zn0+KNAnbpp4rH1tXymmgXQcgVC
# z1E/Ey8NEsvZ1FjV5QP6ovDMT8YAo7KzaYvT4Ix+xMVvW+1/1MnYaaoR8bLnQxmT
# ZOMCAwEAAaOCARswggEXMB0GA1UdDgQWBBT20KmFRryt+uTrJ9eIwjyy6Tdj5zAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQCNkVQS6A+BhrfGOCAWo3KcuUa4estp
# zyn+ZLlkh0pJmAJp4EUDrLWsieYCf2oyoc8KjVMC+NHFFVvHLrSMhWnR5FtY6l3Z
# 6Ur9ITBSz64j5wTRRE8vIpQiHVYjRVNPGR2tiqG5nKP5+sD0rZI464OFNz4n7erD
# JOpV7Im1L/sAwfX+GHoc4j5rfuAuQTFY82sdYvtHM4LTxwV997uhlFs52oHapdFW
# 1KXt6vMxEXnSX8soQfUd+M+Yq3J7udc6R941Guxfd6A0vecV56JjvmpCng4jRkqu
# Aeyf/dKmQUaR1fKvALBRAmZkAUtWijS/3MkeQv/lUvHVo7GPFzJ/O3wJMIIGcTCC
# BFmgAwIBAgIKYQmBKgAAAAAAAjANBgkqhkiG9w0BAQsFADCBiDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMpTWljcm9zb2Z0IFJv
# b3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMTAwNzAxMjEzNjU1WhcN
# MjUwNzAxMjE0NjU1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAKkdDbx3EYo6IOz8E5f1+n9plGt0
# VBDVpQoAgoX77XxoSyxfxcPlYcJ2tz5mK1vwFVMnBDEfQRsalR3OCROOfGEwWbEw
# RA/xYIiEVEMM1024OAizQt2TrNZzMFcmgqNFDdDq9UeBzb8kYDJYYEbyWEeGMoQe
# dGFnkV+BVLHPk0ySwcSmXdFhE24oxhr5hoC732H8RsEnHSRnEnIaIYqvS2SJUGKx
# Xf13Hz3wV3WsvYpCTUBR0Q+cBj5nf/VmwAOWRH7v0Ev9buWayrGo8noqCjHw2k4G
# kbaICDXoeByw6ZnNPOcvRLqn9NxkvaQBwSAJk3jN/LzAyURdXhacAQVPIk0CAwEA
# AaOCAeYwggHiMBAGCSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBTVYzpcijGQ80N7
# fEYbxTNoWoVtVTAZBgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMC
# AYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNVHSMEGDAWgBTV9lbLj+iiXGJo0T2UkFvX
# zpoYxDBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20v
# cGtpL2NybC9wcm9kdWN0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcmwwWgYI
# KwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5j
# b20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNydDCBoAYDVR0g
# AQH/BIGVMIGSMIGPBgkrBgEEAYI3LgMwgYEwPQYIKwYBBQUHAgEWMWh0dHA6Ly93
# d3cubWljcm9zb2Z0LmNvbS9QS0kvZG9jcy9DUFMvZGVmYXVsdC5odG0wQAYIKwYB
# BQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AUABvAGwAaQBjAHkAXwBTAHQAYQB0AGUA
# bQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAAfmiFEN4sbgmD+BcQM9naOh
# IW+z66bM9TG+zwXiqf76V20ZMLPCxWbJat/15/B4vceoniXj+bzta1RXCCtRgkQS
# +7lTjMz0YBKKdsxAQEGb3FwX/1z5Xhc1mCRWS3TvQhDIr79/xn/yN31aPxzymXlK
# kVIArzgPF/UveYFl2am1a+THzvbKegBvSzBEJCI8z+0DpZaPWSm8tv0E4XCfMkon
# /VWvL/625Y4zu2JfmttXQOnxzplmkIz/amJ/3cVKC5Em4jnsGUpxY517IW3DnKOi
# PPp/fZZqkHimbdLhnPkd/DjYlPTGpQqWhqS9nhquBEKDuLWAmyI4ILUl5WTs9/S/
# fmNZJQ96LjlXdqJxqgaKD4kWumGnEcua2A5HmoDF0M2n0O99g/DhO3EJ3110mCII
# YdqwUB5vvfHhAN/nMQekkzr3ZUd46PioSKv33nJ+YWtvd6mBy6cJrDm77MbL2IK0
# cs0d9LiFAR6A+xuJKlQ5slvayA1VmXqHczsI5pgt6o3gMy4SKfXAL1QnIffIrE7a
# KLixqduWsqdCosnPGUFN4Ib5KpqjEWYw07t0MkvfY3v1mYovG8chr1m1rtxEPJdQ
# cdeh0sVV42neV8HR3jDA/czmTfsNv11P6Z0eGTgvvM9YBS7vDaBQNdrvCScc1bN+
# NR4Iuto229Nfj950iEkSoYIC0jCCAjsCAQEwgfyhgdSkgdEwgc4xCzAJBgNVBAYT
# AlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYD
# VQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBP
# cGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpG
# N0E2LUUyNTEtMTUwQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAKnbLAI8fhO58SCWrpZnXvXEZshGggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOVThfEwIhgPMjAyMTEyMDIyMTUwNDFaGA8yMDIxMTIwMzIxNTA0MVowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA5VOF8QIBADAKAgEAAgIm/gIB/zAHAgEAAgIRbDAK
# AgUA5VTXcQIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBAGWkLaXOIljpW4XI
# 5IRKlWvgmbqTkkOLt80/SvCWNS7/O/7icTwd3uNd70aIc8RohCCcsrDvHFELWnzW
# DEvKBnaIFlcfBWaBnbD7GbmHqbHiGA83sgVFQBTAvHhxhy4ZUz00BHoXIxgHjAKC
# gfbp0inCQJV4z+PzSNg5mwBIgFWTMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAFZn/x+Xyzq8kMAAAAAAVkwDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgcNy1cWqsQ3NGa/DoKn8M27YV9ZKTH5+9VMfNhG6S5wgwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCABWBvPvzDmfNeSzmJT4+dGA+uj/qq7/fKkUn36
# rxND6DCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# WZ/8fl8s6vJDAAAAAAFZMCIEIIof7OT71LmghpHtdJP5LelJto1QG/izj0gsUPF1
# zS0GMA0GCSqGSIb3DQEBCwUABIIBAIPxcC+Y2u+FQl/5KRYWueF9nzU2HRGojiCI
# hH6Irw3Y8zXNvFjx0/PAAeUpzKN2csXuuGfxaseJ5hNBAWZp9XyZTLU1/rH1Zkut
# T4jvVOT25wrXqTLmIJkGU6rom4v03bG4tK6Wc1lnEqjKzAVUzi+WhnrSu6GIG+Oa
# 3PqB8F8WmMP5s/Yg0hPgg1V3sujNZSi94qf1RFdvYfye2hz+1EfpQJtkaMmlsORu
# aZkm5l9v0UanRIRehk5ejPMTFAc8xjUaq5UbMHVC5Lw1x02joRhZLCaGPZZrxfdm
# qKc4B55oAmmRfWrMotjWUpBEbZJyYuXKBcCiNdbvk1+EOk/Xb3M=
# SIG # End signature block