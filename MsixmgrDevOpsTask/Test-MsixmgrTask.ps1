Import-Module .\MsixmgrTask\ps_modules\VstsTaskSdk -ArgumentList @{ NonInteractive = $true }

$env:LOCAL_DEBUG = $true
$env:INPUT_VHDFILENAME = "apps.vhdx"
$env:INPUT_VHDSIZE = "500"
$env:INPUT_ROOTAPPSDIRECTORY = "apps"
$env:INPUT_STORAGEACCOUNTNAME = "msixmgrstorage"
$env:INPUT_STORAGEMSIXCONTAINER = "msixpackages"
$env:INPUT_STORAGEVHDCONTAINER = "vhds"
$env:INPUT_LOCATION = "westus"

Invoke-VstsTaskScript -ScriptBlock { . .\MsixmgrTask\MsixmgrTask.ps1 }
