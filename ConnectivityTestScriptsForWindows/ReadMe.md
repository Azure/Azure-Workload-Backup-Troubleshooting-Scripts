# Azure Backup Windows Workload Connectivity Test Scripts

> Contains script to test network connection to required services
> and dependent resource providers ( Azure Active Directory and Azure Storage )
> from the workload machine.

## Usage

1. Download all the scripts from this directory on the machine where you want to test the connectivity.
2. Run the script Start-ConnectivityTests.ps1 


```powershell
    .\Start-ConnectivityTests.ps1 
```

If your Recovery Services vault has a private endpoint, run the script with IsPrivateEndpointEnabled switch

```powershell
    .\Start-ConnectivityTests.ps1 -IsPrivateEndpointEnabled
```

3. If the machine is not registered with Azure Recovery Services Vault (ABRS) vault, trigger the discovery operation for workload backup from the ABRS vault, and wait for script to run connection tests.
Else, the script will automatically start connection tests. The script will prepare a report ReportPage.html in the script's directory.

4. Open the ReportPage.html for the report.

## How to read Azure Workload Backup Conectivity Status report 

| Test| Description |
|---|---|
|DNS resolution tests  | For private endpoint configured recovery services vault, checks the resolution for azure backup services and azure storage account. Follow the guidance in case, resolution for Azure backup service or storage account is failing.|
|Connection Tests   | Runs connectivity tests for Azure active directory, Azure backup service and Azure storage. On connection failures, the report page provides the guidance (Red block) for resolving the connection issues with the respective service.  |


You can also find the settings ( for eg. TLS/SSL, Proxy Settings ) configured on your machine in the report under the respective section. Follow the instruction in Blue block if you are facing issues with network connectivity.