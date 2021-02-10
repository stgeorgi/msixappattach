# Script that exports AppXDeploymentServer%4Operational and puts in a zip fail

# Event Viewer log to export
$eventViewerLog = "Microsoft-Windows-AppXDeploymentServer%4Operational.evtx"
# Event View location 
$eventViewerLogsPath = $env:windir + '\System32\winevt\Logs\'
# Define source path
$eventViewerLogSrc = ($eventViewerLogsPath + $eventViewerLog)
# Random seed
$salt = get-date -uformat %s
# Prepare destination folder 
$eventViewerLogDest = ("c:\temp\EventLogs" + $salt)
New-Item -ItemType Directory -Force -Path $eventViewerLogDest > $null
# Take Event View src file to export destination
Copy-Item -Path $eventViewerLogSrc -Destination $eventViewerLogDest -Force
# Zip content
Write-Progress -Activity 'Creating Zip Archive' -Id 10041
Add-Type -Assembly "System.IO.Compression.FileSystem";
[System.IO.Compression.ZipFile]::CreateFromDirectory($eventViewerLogDest, $($eventViewerLogDest + 'logs'  + ".zip"));
Write-Progress -Activity 'Done' -Completed -Id 10041
# Confirm and exit
Write-Host $($eventViewerLogDest + 'logs'  + ".zip")
Pause
