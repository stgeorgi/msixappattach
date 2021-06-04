<#
    .SYNOPSIS
        Create VHD(X) from MSIX packages.
    .DESCRIPTION
        Create VHD(X) from MSIX packages.
    .PARAMETER VhdFileName
        The path of the VHD(X) file to be created.
    .PARAMETER VhdSize
        The size of the VHD(X) in megabytes.
    .PARAMETER RootAppsDirectory
        The directory on the VHD(X) where the MSIX packages will be installed.
    .PARAMETER StorageConnectionString
        The connection string of the storage account that contains the MSIX packages.
    .PARAMETER StorageMsixContainer
        The blob container where the MSIX packages are located.
#>

param(
    [String]
    [ValidateNotNullOrEmpty()]
    $VhdFileName = "apps.vhdx",

    [Int64]
    $VhdSize = 1024,

    [String]
    [ValidateNotNullOrEmpty()]
    $RootAppsDirectory = "apps",

    [String]
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $StorageConnectionString,

    [String]
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $StorageMsixContainer,

    [String]
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $StorageVhdContainer
)

$workingPath = "c:\msix"
$msixmgrUrl = "https://aka.ms/msixmgr"
$msixmgrZipDestination = Join-Path $workingPath "msixmgr.zip"
$msixmgrDestination = Join-Path $workingPath "msixmgr"
$msixPackagesPath = Join-Path $workingPath "packages"
$msixmgrExe = Join-Path (Join-Path $msixmgrDestination "x64") "msixmgr.exe"
$vhdDirectoryPath = Join-Path $workingPath "vhd"
$vhdFilePath = Join-Path $vhdDirectoryPath $VhdFileName
$vhdFileExtension = [IO.Path]::GetExtension($VhdFileName).Substring(1)
$vhdFileNameWithoutExtension = [IO.Path]::GetFileNameWithoutExtension($VhdFileName)

# Need to set tls to 1.2 or you can't install the nuget package
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Verify Az.Storage module is installed
if (-not (Get-Module -ListAvailable -Name "Az.Storage")) {        
    # In order to install the Az.Storage module, you have to have the NuGet Package Provider.
    Write-Host "Installing NuGet Package Provider."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
        
    Write-Host "Installing 'Az.Storage' module."
    Install-Module -Name "Az.Storage" -Repository PSGallery -Force | Out-Null
}

# cleanup
# delete working folder
if (Test-Path -Path $workingPath) {
    Remove-Item -LiteralPath $workingPath -Recurse -Force
}

# create directories
# Create working directory
New-Item  -Path $workingPath -ItemType Directory -Force | Out-Null
# Create packages directory
New-Item  -Path $msixPackagesPath -ItemType Directory -Force | Out-Null
# Create vhd directory
New-Item  -Path $vhdDirectoryPath -ItemType Directory -Force | Out-Null

# Download MSIXMGR
Start-BitsTransfer -Source $msixmgrUrl -Destination $msixmgrZipDestination

# unzip MSIXMGR
Expand-Archive -Path $msixmgrZipDestination -DestinationPath $msixmgrDestination

# download msix packages
$storageContext = New-AzStorageContext -ConnectionString $StorageConnectionString
Get-AzStorageBlob -Context $storageContext -Container $StorageMsixContainer | Get-AzStorageBlobContent -Force -Destination $msixPackagesPath | Out-Null

# create vhd(x)/cim
& $msixmgrExe -Unpack -packagePath $msixPackagesPath -destination $vhdFilePath -ApplyACLs -create -vhdSize $vhdSize -filetype $vhdFileExtension -rootDirectory $RootAppsDirectory   

# Verify that vhd created. If the previous command fails, the script continues anyway.
if (-not (Test-Path $vhdFilePath)) {
    throw "Error: '$vhdFilePath' was not created."
}

$outputFilePath = $vhdFilePath
$outputFileName = $VhdFileName

# If the type is a CIM, there are multiple files that need to be put into a zip
if ($vhdFileExtension -eq "cim") {
    $outputFileName = "$vhdFileNameWithoutExtension.zip"
    $outputFilePath = Join-Path $vhdDirectoryPath $outputFileName
    Compress-Archive -Path "$vhdDirectoryPath\*" -DestinationPath $outputFilePath
}

# copy vhd to azure storage
$storageEndpointUrl = $storageContext.BlobEndPoint + $StorageVhdContainer + "/" + $outputFileName
Write-Host "`nCopying '$outputFilePath' to '$storageEndpointUrl'"
Set-AzStorageBlobContent -Context $storageContext -File $outputFilePath -Container $StorageVhdContainer -Force | Out-Null
