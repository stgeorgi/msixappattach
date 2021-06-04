[CmdletBinding()]
param()

Trace-VstsEnteringInvocation $MyInvocation

try {
    $local = $env:LOCAL_DEBUG
    if ($local) {
        Write-Warning "Running in local debug mode."
    }

    ###########################
    # Get Parameters
    $VhdFileName = Get-VstsInput -Name vhdFileName -Require
    $VhdSize = Get-VstsInput -Name vhdSize -Require
    $RootAppsDirectory = Get-VstsInput -Name rootAppsDirectory -Require
    $StorageAccountName = Get-VstsInput -Name storageAccountName -Require
    $StorageMsixContainer = Get-VstsInput -Name storageMsixContainer -Require
    $StorageVhdContainer = Get-VstsInput -Name storageVhdContainer -Require
    $Location = Get-VstsInput -Name location -Require
    $suffix = ( -join ((0x30..0x39) + ( 0x41..0x5A) + ( 0x61..0x7A) | Get-Random -Count 10  | ForEach-Object { [char]$_ }) )

    ###########################
    # Install Modules
    $modules = 'Az.Accounts', 'Az.Resources', 'Az.Network', 'Az.Compute', 'Az.Storage'
    Write-Host "Installing Azure Modules..."
    foreach ($module in $modules) {
        if (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue) {
            Write-Host "Module '$module' is already installed."            
        }
        else {
            Write-Host "Installing Module '$module'..."        
            Install-Module -Name $module -AllowClobber -Scope CurrentUser -Force
        }
    }

    ###########################
    # Connect to Azure
    if (!$local) {
        Write-Host "Connecting to Azure..."
        $connectedServiceName = Get-VstsInput -Name ConnectedServiceName -Require
        $endpoint = Get-VstsEndpoint -Name $connectedServiceName -Require
    
        if (!$endpoint) {
            throw "Endpoint not found..."
        }
        $subscriptionId = $endpoint.Data.SubscriptionId
        $tenantId = $endpoint.Auth.Parameters.TenantId
        $servicePrincipalId = $endpoint.Auth.Parameters.servicePrincipalId
        $servicePrincipalKey = $endpoint.Auth.Parameters.servicePrincipalKey
    
        $spnKey = ConvertTo-SecureString $servicePrincipalKey -AsPlainText -Force
        $credentials = New-Object System.Management.Automation.PSCredential($servicePrincipalId, $spnKey)
    
        Disable-AzContextAutosave | Out-Null
        Connect-AzAccount -ServicePrincipal -TenantId $tenantId -SubscriptionId $subscriptionId -Credential $credentials | Out-Null
    
    }

    # Verify connection to Azure
    $ctx = Get-AzContext
    Write-Host "Connected to subscription '$($ctx.Subscription)'..."
    
    ###########################
    # Validation
    Write-Host "Validating parameters..."
    # Validate $StorageAccountName
    try {
        $storageAccount = Get-AzStorageAccount | Where-Object StorageAccountName -EQ $StorageAccountName | Select-Object -First 1
        $storageContext = $storageAccount.Context
        $StorageConnectionString = $storageContext.ConnectionString
    }
    catch {
        Write-Error "Could not connect to Azure Storage: $($_.Exception.Message)"
    }
    # Validate $StorageMsixContainer
    try {
        $msixBlob = Get-AzStorageBlob -Context $storageContext -Name $StorageMsixContainer -Blob "*.msix"
        # Display a warning if there are no msix files
        if ($msixBlob.Length -le 0) {
            Write-Warning "There are no files with the extension 'msix' in the container '$StorageMsixContainer'."
        }
    }
    catch {
        Write-Error "The parameter 'Azure Blob Storage MSIX Container' is not valid: $($_.Exception.Message)"        
    }

    # Validate $StorageVhdContainer
    try {
        Get-AzStorageBlob -Context $storageContext -Name $StorageVhdContainer | Out-Null
    }
    catch {
        Write-Error "The parameter 'Azure Blob Storage VHD Container' is not valid: $($_.Exception.Message)"        
    }

    # Validate $Location
    if (!(Get-AzLocation | Where-Object { $_.DisplayName -eq $Location -or $_.Location -eq $Location } )) {
        Write-Error "The location '$Location' is not valid."
    }
    # Validate $VhdFileName
    $validFileTypes = "vhd", "vhdx", "cim"
    $fileType = [IO.Path]::GetExtension($VhdFileName).Substring(1)
    if ($fileType -notin $validFileTypes ) {
        Write-Error "The 'VHD File Name' must one of the following extensions: $([System.String]::Join(", ", $validFileTypes))."
    }

    # Validate $RootAppsDirectory
    try {
        [System.IO.FileInfo]$RootAppsDirectory | Out-Null
    }
    catch {
        Write-Error "'VHD Apps Directory' is not valid: $($_.Exception.Message)"
    }

    # Validate $VhdSize
    try {
        [Int64]$VhdSize | Out-Null
    }
    catch {
        Write-Error "'VHD Size (MB)' is not valid: $($_.Exception.Message)"        
    }

    ###########################
    # Create RG
    $ResourceGroupName = "rg-$suffix"
    Write-Host "Creating resource group '$ResourceGroupName' at the location '$Location'."
    
    # Validate that RG doesn't already exist
    if (Get-AzResourceGroup $ResourceGroupName -ErrorAction SilentlyContinue) {
        throw "The resource group '$ResourceGroupName' exists. You cannot use an resource group that already exists."
    }

    New-AzResourceGroup -Name $ResourceGroupName -Location $Location | Out-Null
    try {
        ###########################
        # Create subnet
        $subnetName = "subnet-$suffix"
        Write-Host "Creating Subnet '$subnetName'..."
        $subnet = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix "10.0.0.0/24"

        ###########################
        # Create vnet
        $vnetName = "vnet-$suffix"
        Write-Host "Creating VNet '$vnetName'..."
        $vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix "10.0.0.0/16" -Subnet $subnet

        ###########################
        # Create public ip if debugging
        $publicIpAddressId = $null
        if ($local) {
            $publicIpAddressName = "ip-$suffix"
            Write-Host "Creating public ip '$publicIpAddressName'..."
            $publicIp = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Location $Location -Name $publicIpAddressName -AllocationMethod Dynamic
            $publicIpAddressId = $publicIp.Id
        }

        ###########################
        # Create nic
        $nicName = "nic-$suffix"
        Write-Host "Creating NIC '$nicName'..."
        $nic = New-AzNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Location $Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIpAddressId

        ###########################
        # Create VM
        $VmName = "vm$suffix"
        Write-Host "Creating VM '$VmName'..."

        # Generate random password        
        $VmPwd = ConvertTo-SecureString (.$PSScriptRoot\Create-Password.ps1 -Size 20 -Complexity "ULN") -AsPlainText -Force
        $VmAdminCredential = (New-Object System.Management.Automation.PSCredential("devadmin", $VmPwd))
    
        $VirtualMachine = New-AzVMConfig -VMName $VmName -VMSize "Standard_DS3_v2"
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName "vm-$VmName" -Credential $VmAdminCredential -ProvisionVMAgent -EnableAutoUpdate
        $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id
        $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsDesktop' -Offer 'Windows-10' -Skus '21h1-ent-g2' -Version latest
        $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable
        $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -DiffDiskSetting Local -Caching ReadOnly -CreateOption FromImage
    
        New-AzVM -ResourceGroupName $ResourceGroupName -Location $Location -VM $VirtualMachine | Out-Null
   
        ###########################
        # Wait for VM to be ready
        $isReady = $false
        while ($isReady -eq $false) {
            $vm = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status)
            $isReady = ($vm.VMAgent.Statuses | ForEach-Object { $_.DisplayStatus -match "Not Ready" }) -contains $false
            if ($isReady) {
                Write-Host "VM is ready!"
            }
            else {
                Write-Host "Waiting for the VM to be ready..."
                Start-Sleep -Seconds 10
            }
        }

        ###########################
        # Run script on VM that will create VHD
        Write-Host "Creating VHD(X)..."
        $params = @{ 
            VhdFileName             = $VhdFileName;
            VhdSize                 = $VhdSize;
            RootAppsDirectory       = $RootAppsDirectory;
            StorageConnectionString = $StorageConnectionString;
            StorageMsixContainer    = $StorageMsixContainer;
            StorageVhdContainer     = $StorageVhdContainer;
        }

        $result = Invoke-AzVMRunCommand `
            -ResourceGroupName $ResourceGroupName `
            -Name $VmName `
            -CommandId "RunPowerShellScript" `
            -ScriptPath (Join-Path $PSScriptRoot "New-MsixVhd.ps1") `
            -Parameter $params

        # display output of Invoke-AzVMRunCommand
        foreach ($item in $result.Value) {
            Write-Host $item.Message
        }
    }
    catch {
        Write-Error $_.Exception.Message        
    }
    finally {
        # Delete RG
        Write-Host "Deleting the resource group '$ResourceGroupName'..."
        Remove-AzResourceGroup -Name $ResourceGroupName -Force | Out-Null     
    }
}
finally {
    Trace-VstsLeavingInvocation $MyInvocation
}
