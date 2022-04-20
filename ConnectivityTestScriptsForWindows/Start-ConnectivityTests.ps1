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
    This script runs connectivity checks for Azure Backup service, Azure Storage and Azure Active Directory.
    Reports the connectivity status for all the required services.
.DESCRIPTION  
    This script runs connectivity checks for Azure Backup service, Azure Storage and Azure Active Directory.
    Reports the connectivity status for all the required services.
.PARAMETER IsPrivateEndpointEnabled
    Specifies if the workload is protected with RS Vault with private endpoint
.PARAMETER RegisteredObjectCatalogDirPath
    Specifies the path to container catalog which contains Auth details and Service URLs
.PARAMETER ConfigJsonDirPath
    Specifies the path to Azure Workload Backup bin directory
.PARAMETER LogFilePath
    Specifies the file path to which the output of the script will be written.
#>

Param(
    [switch]$IsPrivateEndpointEnabled,

    [parameter(position=0, Mandatory=$false)]
    $RegisteredObjectCatalogDirPath = "C:\Program Files\Azure Workload Backup\Catalog\RegisteredObjectInfoCatalog\RegisteredObjectInfoTable",

    [parameter(position=1, Mandatory=$false)]
    $ConfigJsonDirPath ="C:\Program Files\Azure Workload Backup\bin",

    [parameter(position=1, Mandatory=$false)]
    $LogFilePath ="TestLogs.log"
    )

# Context
$ScriptRoot = $PSCommandPath.Replace("\Start-ConnectivityTests.ps1", "")
$ActiveDirectoryDllPath = "$ScriptRoot\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$DiagnosticScriptsDllPath = "$ScriptRoot\DiagnosticScripts.dll"
$NewtonsoftJsonDllPath = "$ScriptRoot\Newtonsoft.Json.dll"
$Report = [xml] (Get-Content "$ScriptRoot\ReportDetails.xml")

Unblock-File $ActiveDirectoryDllPath
Unblock-File $DiagnosticScriptsDllPath
Unblock-File $NewtonsoftJsonDllPath

# Constants
$Fabric = "Fabric"
$BCM = "BCM"
$WLBCM = "WLBCM"
$Protection = "Protection"
$IdMgmt = "IdMgmt"
$ECS = "ECS"
$Telemetry = "Telemetry"

if ($LogFilePath -eq "TestLogs.log")
{
    $FileName = "TestLogs.log"
    $LogFilePath = $ScriptRoot + "\$FileName"
    $DllLogFilePath = $ScriptRoot + "\Dll" + "$FileName"
}

## Tracer
function TraceMessage([string] $message, [string] $color="Yellow")
{
    Write-Host "`n$message" -ForegroundColor $color
    $("`n[$([DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss"))] $message") | Out-File -FilePath $LogFilePath -Append -Encoding UNICODE -Confirm:$false
}

#Loading assembly files
try
{
    Add-Type -Path $ActiveDirectoryDllPath
    TraceMessage "`nLoaded ADAL library from $ActiveDirectoryDllPath"
    Add-Type -Path $DiagnosticScriptsDllPath
    TraceMessage "`nLoaded $DiagnosticScriptsDllPath"
}
catch
{
    TraceMessage "`n $($_.Exception.Message)"
    TraceMessage "`n $($_.Exception.StackTrace)"
}

# Read RegisteredCatalogObject Table
$RegisteredObjectFilePath = $null

while ($RegisteredObjectFilePath -eq $null )
{
    TraceMessage "`n Waiting for the RegistrationObjectCatalogTable file. Trigger Discovery from portal."
    Start-Sleep -s 1
    if (Test-Path $RegisteredObjectCatalogDirPath)
    {
        $RegisteredObjectFilePath = ((Get-ChildItem -Path $RegisteredObjectCatalogDirPath).FullName | Where {$_ -match ".*.bin"})
    }
}

TraceMessage "`n Using $RegisteredObjectFilePath"

try
{
    TraceMessage "`nCurrent TLS Settings $([System.Net.ServicePointManager]::SecurityProtocol)" "Cyan"
    TraceMessage "`nFetching AAD token..."

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls -bor  [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls12
    
    $ro = Get-Content $RegisteredObjectFilePath -raw | ConvertFrom-Json
    $bytes = [System.Convert]::FromBase64String($ro.ObjectAuthProperties.Cert)
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(, $bytes)
    $authContext = new-object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext -ArgumentList $ro.ObjectAuthProperties.Authority
    $clientAssert = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.ClientAssertionCertificate -ArgumentList @($ro.ObjectAuthProperties.ClientId, $cert)

    $error.Clear()
    $authenticationResult = $authContext.AcquireTokenAsync($ro.ObjectAuthProperties.Audience, $clientAssert, $true).Result

    if ($authenticationResult -ne $null -and [string]::IsNullOrWhiteSpace($authenticationResult.AccessToken) -eq $false)
    {
        TraceMessage "`nToken fetched successfully" "Green"
        $Report.report.ConnectivityTests.AAD.Status = "Green"

        # Test Private endpoint related connections
        if( $IsPrivateEndpointEnabled.IsPresent )
        {
            $services = $BCM,$Protection,$IdMgmt,$ECS,$Fabric,$Telemetry

            foreach ($service in $services)
            {
                $urlPrefix = "https://"
                $serviceUrl = "$($ro.ResourceId)-ab-" + $ro.ObjectServiceUrls.$service.Substring( $urlPrefix.Length, $ro.ObjectServiceUrls.$service.IndexOf(".")-$urlPrefix.Length) + "$(".privatelink." + $ro.ObjectServiceUrls.$service.Substring($ro.ObjectServiceUrls.$service.IndexOf(".")+1))"

                $dns = $Report.report.PrivateEndpointTests.DNSResolutions.DNS[0].Clone()
                $dns.DNSEntry = $serviceUrl

                try
                {
                    TraceMessage "`nTesting DNS resolution $serviceUrl"

                    $error.clear()
                    $privateip = $null
                    $privateip = Resolve-DnsName $serviceUrl -ErrorAction SilentlyContinue

                    if( $privateip -eq $null)
                    {
                        TraceMessage "`nFailed to resolve1 $serviceUrl"  "Red"
                        $dns.PrivateIp = $error[0].ToString()
                    }
                    else
                    {
                        $dns.PrivateIp = $privateip.IPAddress
                    }

                    $Report.report.PrivateEndpointTests.DNSResolutions.AppendChild($dns)
                    $Report.report.PrivateEndpointTests.DNSResolutions                   
                   
                }
                catch
                {
                    TraceMessage "`nFailed to resolve $serviceUrl"  "Red"
                    TraceMessage $_
                }
            }

            $fabricSvcUrl = "$($ro.ResourceId)-ab-" + $ro.ObjectServiceUrls.Fabric.Substring($urlPrefix.Length,$ro.ObjectServiceUrls.Fabric.IndexOf(".")-$urlPrefix.Length) + "$(".privatelink." + $ro.ObjectServiceUrls.Fabric.Substring($ro.ObjectServiceUrls.Fabric.IndexOf(".")+1))"
            $wlbcmSvcUrl = "$($ro.ResourceId)-ab-" + $ro.ObjectServiceUrls.BCM.Substring($urlPrefix.Length,$ro.ObjectServiceUrls.BCM.IndexOf(".")-$urlPrefix.Length) + "$(".privatelink." + $ro.ObjectServiceUrls.BCM.Substring($ro.ObjectServiceUrls.BCM.IndexOf(".")+1))"

            $fabricChannelEncryptionKeyUrl = $urlPrefix + "$fabricSvcUrl/resources/$($ro.ResourceId)/containers/$($ro.IdMgmtContainerId)/ChannelEncryptionKeys"
            $wlbcmChannelEncryptionKeyUrl = $urlPrefix + "$wlbcmSvcUrl/resources/$($ro.ResourceId)/containers/$($ro.IdMgmtContainerId)/ChannelEncryptionKeys"
        }
        else
        {
            $fabricChannelEncryptionKeyUrl = "$($ro.ObjectServiceUrls.Fabric)/resources/$($ro.ResourceId)/containers/$($ro.IdMgmtContainerId)/ChannelEncryptionKeys"
            $wlbcmChannelEncryptionKeyUrl = "$($ro.ObjectServiceUrls.BCM)/resources/$($ro.ResourceId)/containers/$($ro.IdMgmtContainerId)/ChannelEncryptionKeys"        
        }

        # Format Header
        $headers = @{}
        $headers.Add("Authorization", "Bearer "+ " " + "$($authenticationResult.AccessToken)")
                
        $tlsSettings = [System.Net.SecurityProtocolType]::Tls, [System.Net.SecurityProtocolType]::Tls11, [System.Net.SecurityProtocolType]::Tls12
        $fabricStatus = $Report.report.ConnectivityTests.Services.Service.Clone()
        $fabricStatus.Name = $Fabric
        $wlbcmStatus = $Report.report.ConnectivityTests.Services.Service.Clone()
        $wlbcmStatus.Name = $WLBCM

        $serviceStatuses = $fabricStatus, $wlbcmStatus
        $serviceUrlMap = @{$Fabric=$fabricChannelEncryptionKeyUrl ; $WLBCM=$wlbcmChannelEncryptionKeyUrl}
        $serviceUrlMap
        foreach ( $tlsSetting in $tlsSettings)
        {
            TraceMessage "`n=============Trying TLS $tlsSetting==================="  "Yellow"
            [System.Net.ServicePointManager]::SecurityProtocol = $tlsSetting
            
            TraceMessage "$([System.Net.ServicePointManager]::SecurityProtocol)"  "Cyan"

            foreach ( $serviceStatus in $serviceStatuses)
            {
                TraceMessage "`nPinging $($serviceUrlMap[$($serviceStatus.Name)])"  "Yellow"

                try
                {
                    #Invoke REST API
                    $response = Invoke-RestMethod -Method Get -Uri $($serviceUrlMap[$($serviceStatus.Name)]) -Headers $Headers
                    TraceMessage "`n$($serviceStatus.Name) Call successful"  "Green"
                    $serviceStatus.$tlsSetting = "Green"
                }
                catch
                {
                    TraceMessage "`n$($serviceStatus.Name) Call failed"  "Red"
                    TraceMessage $_.Exception.Message
                    TraceMessage $_.Exception.StackTrace
                    $serviceStatus.$tlsSetting = $_.Exception.Message
                }

                $Report.report.ConnectivityTests.Services.AppendChild($serviceStatus)
            }
        }
    }
    else
    {
        TraceMessage "`nToken fetch failed"  "Red"
        $Report.report.ConnectivityTests.AAD.Status = "Red"
        $Report.report.ConnectivityTests.AAD.Exception = $error
    }
}
catch
{
    TraceMessage "`nToken fetch failed"  "Red"
    TraceMessage $_.Exception.StackTrace

    $Report.report.ConnectivityTests.AAD.Status = "Red"
    $Report.report.ConnectivityTests.AAD.Exception = $_.Exception.StackTrace
}

#Storage connection tests
try
{
    [Microsoft.Internal.CloudBackup.WorkloadExtension.DiagnosticScripts.WorkloadExtensionDiagnosticHelper] $workloadExtensionDiagnosticHelper = New-Object Microsoft.Internal.CloudBackup.WorkloadExtension.DiagnosticScripts.WorkloadExtensionDiagnosticHelper
    
    if ( $IsPrivateEndpointEnabled.IsPresent)
    {
        $dns = $Report.report.PrivateEndpointTests.DNSResolutions.DNS[0].Clone()

        try
        {
            $dnsMap = $workloadExtensionDiagnosticHelper.TryResolveStoragePrivateUrl("$ConfigJsonDirPath\AzureWLBackupCoordinatorSvc_config.json", $DllLogFilePath)  | ConvertFrom-Json
            if ($dnsMap -eq $null -or ($dnsMap.DNSEntry -eq $null) )
            {
                TraceMessage "`nFailed to resolve storage url"  "Red"
            }
            else
            {
                $dns.DNSEntry = $dnsMap.DNSEntry.ToString()
                $dns.PrivateIp = $dnsMap.PrivateIp
            }

            $Report.report.PrivateEndpointTests.DNSResolutions.AppendChild($dns)
        }
        catch
        {
            TraceMessage "`nFailed to resolve storage url"  "Red"
            TraceMessage $_
        }
    }

    $tlsSettings = [System.Net.SecurityProtocolType]::Tls, [System.Net.SecurityProtocolType]::Tls11, [System.Net.SecurityProtocolType]::Tls12
    $storageStatus = $Report.report.ConnectivityTests.Storage

    foreach ( $tlsSetting in $tlsSettings)
    {
        TraceMessage "`n=============Trying TLS $tlsSetting==================="  "Yellow"
        TraceMessage "`nPinging Storage"  "Yellow"

        try
        {
            #Invoke REST API
            $storageStatus.$tlsSetting = if ($workloadExtensionDiagnosticHelper.TestConnectionForStorage("$ConfigJsonDirPath\AzureWLBackupCoordinatorSvc_config.json",  $tlsSetting, $DllLogFilePath)) {"Green"} else {"Red"}

            if ($storageStatus.$tlsSetting -eq "Green")
            {
                TraceMessage "`nStorage Call successful"  "Green"
            }
            else
            {
                TraceMessage "`nStorage Call failed"  "Red"
            }
        }
        catch
        {
            TraceMessage "`nStorage Call failed"  "Red"
            TraceMessage $_.Exception.Message
            TraceMessage $_.Exception.StackTrace
            $storageStatus.$tlsSetting = $_.Exception.Message
        }
    }
}
catch
{
    TraceMessage "`nConnectivity tests failed for Storage account" "Red"
    TraceMessage $_.Exception.StackTrace
}

#TLS Settings

TraceMessage "`n=============Fetching TLS settings==================="  "Yellow"

try
{
    $CurrentDefaultSettings =  ‘{0:x}‘ -f  (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue).SecureProtocols
    $DefaultSettings = ""
    if ( ($CurrentDefaultSettings[-2] -eq '8' ) -or ($CurrentDefaultSettings[-2] -eq 'a') )
    {
        $DefaultSettings = "TLS 1.0;" + $DefaultSettings
    }
    if ( ($CurrentDefaultSettings[-3] -eq '2' ) -or ($CurrentDefaultSettings[-3] -eq 'a') )
    {
        $DefaultSettings = "TLS 1.1;" + $DefaultSettings
    }
    if ( ($CurrentDefaultSettings[-3] -eq '8' ) -or ($CurrentDefaultSettings[-3] -eq 'a') )
    {
        $DefaultSettings = "TLS 1.2;" + $DefaultSettings
    }

    $Report.report.TLSSettings.DefaultSettings = $DefaultSettings

    $tlsSettings = [System.Net.SecurityProtocolType]::Tls, [System.Net.SecurityProtocolType]::Tls11, [System.Net.SecurityProtocolType]::Tls12
    $TLSSettingsMap = @{[System.Net.SecurityProtocolType]::Tls="TLS 1.0" ; [System.Net.SecurityProtocolType]::Tls11="TLS 1.1" ; [System.Net.SecurityProtocolType]::Tls12="TLS 1.2"}

    foreach ( $tlsSetting in $tlsSettings)
    {
        $tlsVersion = ($("$tlsSetting") | Out-String).Trim()
        $Report.report.TLSSettings."$tlsVersion".Server = ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$($TLSSettingsMap[$($tlsSetting)])\Server" -ErrorAction SilentlyContinue).Enabled | Out-String).Trim()
        $Report.report.TLSSettings."$tlsVersion".Client = ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$($TLSSettingsMap[$($tlsSetting)])\Client" -ErrorAction SilentlyContinue).Enabled | Out-String).Trim()
    }
}
catch
{
    TraceMessage "`nFailed to determine TLS settings" "Red"
}

# Removing Temp file
if ( Test-Path -Path "$ScriptRoot\ProxySettings.txt")
{
    Remove-Item "$ScriptRoot\ProxySettings.txt"
}

. $ScriptRoot\Get-ProxySettings.ps1 -LogFile "$ScriptRoot\ProxySettings.txt"
$proxySettings = Get-Content "$ScriptRoot\ProxySettings.txt"

$Report.report.ProxySettings = "$proxySettings"

# Save Report Details
$Report.Save("$ScriptRoot\Report.xml")

# Create Report
. $ScriptRoot\Publish-Report.ps1 -ReportXmlFile "$ScriptRoot\Report.xml" -ReportHtmlFile "$ScriptRoot\ReportPage.html" -IsPrivateEndpointEnabled:$IsPrivateEndpointEnabled
# SIG # Begin signature block
# MIIjkgYJKoZIhvcNAQcCoIIjgzCCI38CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCzeOefJvuUUpO2
# vvqA8SLdctyJkX2Uv3aHsUoO6RN8wqCCDYEwggX/MIID56ADAgECAhMzAAACUosz
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgcQoY+ZLc
# kK8kRiTsTZuxGf8w7EJlG3xAFqJBMqHiGyAwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQAcIoOjebyLdWFNj7ifJ03krtLqDSdCK3ZR0WJWjKeF
# iUnsLUC8RKJRBZPXo9rodJpO8FBDnR6KXYf+zni0cW3Dnc0/c6iS8CuXl/ZWmUW5
# J/WeAKaDTGr9fvXdYgsLSfTMelTP+dN5J1cSRqHGbN9kWikAek+eAKAvQ3YMUxa/
# s4zZ66Y1oSka9tUfxbeuh+Y6oa+FQug/qFBGMQo1W7Rk/bm49ubO/EyPnflrOs72
# esVl7awxzMlSd1uGZRmLW/nOtjqbpnZpnNdojry0RuIEKLjW85rdYkXCAd9P8p/V
# 0Ff7o+hrtA3ZkQgONA+mdDbqHufoIPjHSFnLSzuRPeG+oYIS8TCCEu0GCisGAQQB
# gjcDAwExghLdMIIS2QYJKoZIhvcNAQcCoIISyjCCEsYCAQMxDzANBglghkgBZQME
# AgEFADCCAVUGCyqGSIb3DQEJEAEEoIIBRASCAUAwggE8AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIFrCk6LM5prfEOvjHmUG/CpenPKZ+K8WyrsQBDe1
# L2cZAgZhk97L+Q0YEzIwMjExMjAzMDQ0MDU0LjYwMlowBIACAfSggdSkgdEwgc4x
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1p
# Y3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMg
# VFNTIEVTTjpGNzdGLUUzNTYtNUJBRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUt
# U3RhbXAgU2VydmljZaCCDkQwggT1MIID3aADAgECAhMzAAABXp0px1+HBaHqAAAA
# AAFeMA0GCSqGSIb3DQEBCwUAMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNo
# aW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29y
# cG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEw
# MB4XDTIxMDExNDE5MDIxOVoXDTIyMDQxMTE5MDIxOVowgc4xCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVy
# YXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpGNzdG
# LUUzNTYtNUJBRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vydmlj
# ZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJrTI4OQehn3oKp2zuh6
# WP2Zib/Dxw/srLeeyTb9ed7PX+fLg7zBA0yl6ivF2n6lauGH8W7EBwRPEv7ZCSXw
# XgYZ6GGaH8aU+OrDXAbc4BXTO5XnLGwSbaye9R2+uQHdCJmaMtz/lEBWUK5xvHoj
# 0TUrXOZdZ/vv7TqMWA4h1AT1w/JBR4kHtV1i8KWdlQ+dZX/gNHpA72IoLoOmpImb
# GRzcGQ4Z2Kzq4eMB9wjaFRV1JF/wz1hLFIjGtlU3eGjRBiBEEVI7UEMMSvI4rK+C
# fLAIZnULu7SzlIfqSU3R0pSNUahwpWdCiB6fKzIq94Z+9888moQuo95RAPmzHQW1
# MI0CAwEAAaOCARswggEXMB0GA1UdDgQWBBSqcny6Dd1L5VTCEACezlR41fgfKzAf
# BgNVHSMEGDAWgBTVYzpcijGQ80N7fEYbxTNoWoVtVTBWBgNVHR8ETzBNMEugSaBH
# hkVodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNU
# aW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUF
# BzAChj5odHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1RpbVN0
# YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNVHRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsG
# AQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IBAQB/IfxZhMYkBMqRmXnh/Vit4bfxyioA
# lr7HJ1XDSHTIvRwDD1PGr0upZE/vrrI/QN/1Wi6vDcKmnJ2r7Xj6pWZOZqc9Bp+u
# BvpPaulue4stu3TqKTc9Fu2K5ibctpF4oHPfZ+IKeChop+Mk9g7N5llHzv0aCDia
# M0w2aAT3rj3QHQS8ijnQ5/qhtzwo1AoUnV1y2urWwX5aHdUzaoeAJrvnf2ee89Kf
# 4ycjjyafNJSUp/qaXBlbjMu90vNubJstdSxOtvwcxeeHP6ZaYbTl2cOla4cokiPU
# +BUjIZA/t/IZfYoazMGmBtLWFJZdC9LYWWmLLsNJ2W21qkeSSpEAw4pmMIIGcTCC
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
# NzdGLUUzNTYtNUJBRTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2Vy
# dmljZaIjCgEBMAcGBSsOAwIaAxUAVkmPV/8hZVS9FzbtoX2x3Z2xYyqggYMwgYCk
# fjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMH
# UmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQD
# Ex1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIF
# AOVUHaIwIhgPMjAyMTEyMDMwODM3NTRaGA8yMDIxMTIwNDA4Mzc1NFowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA5VQdogIBADAKAgEAAgIdMAIB/zAHAgEAAgIRXjAK
# AgUA5VVvIgIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIB
# AAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GBALNUOuwXkwR4J050
# MEHhI7u/CqE6eoJrCX+yK5Dc4ltzD7+aG5kzen5g5qSjVq6fAC2VBVpoeBiV9PpZ
# K7Xs/v8mthTfokrKvNh9Skn8ywqhlcCAFyt1C/ynvyUX6OJi+pAZYxAewrxL0V3D
# +tSOrV60iuAUMIY0l81jkjZDvWmUMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTACEzMAAAFenSnHX4cFoeoAAAAAAV4wDQYJYIZIAWUD
# BAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0B
# CQQxIgQgTQC7DmkBowZEQq1rMM0PlP3YxSlpx8ZwGPz6b/bU6uYwgfoGCyqGSIb3
# DQEJEAIvMYHqMIHnMIHkMIG9BCB+5YTslNSXjuB+5mQDTKRkM7prkewhXnevXpLv
# 8RLT4jCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9u
# MRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRp
# b24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAB
# Xp0px1+HBaHqAAAAAAFeMCIEIBQ0rB4b8F+M/hxXvK950Lo4CgbdujLGzq6ppYdb
# UweAMA0GCSqGSIb3DQEBCwUABIIBAJXIi8yPr8ePdW1HbjzZcks0CGRBdF7RTATW
# TKYCF/CtGgqnYL3YE6p1voU1mS0LaefyX3Mz2u5YskkWvI4uOKTy4bIS7W4bFiuM
# XQJly6V2wFxELZtDdi+nq4Byyv3RhGEdgG6hmyeSuVpSBWEdU72LoUVov32voY7j
# qVmnfJq6x/c7ZsUwUrauESaRu2M6tiL9eTB5jEbkA0c+DHQqf3FYqo3F27NJXbo8
# 3FLhVed2hF/ovUgNrTV2urGc/en3g+MdIiz1OCzz6iJ2VmFzFVR+YwwL8EsF5TxT
# T0YGYXwILh4lcRdouME4UE+brvEPZy6q4pN3TNyrJVJbnw3aGdw=
# SIG # End signature block