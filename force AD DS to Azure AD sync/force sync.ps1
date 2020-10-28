[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Find-PackageProvider -Name "Nuget" -AllVersions

Install-PackageProvider -Name "Nuget"

Import-Module –Name "C:\Program Files\Microsoft Azure AD Sync\Bin\ADSync" -Verbose

get-module

get-command -module adsync

Start-ADSyncSyncCycle -PolicyType Delta