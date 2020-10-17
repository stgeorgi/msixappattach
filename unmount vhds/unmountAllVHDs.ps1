$pd = Get-PhysicalDisk
foreach ($p in $pd){ 
    # $p.PhysicalLocation

    if ($p.PhysicalLocation -like "\\advm\*") {
        Dismount-DiskImage -ImagePath $p.PhysicalLocation
    }
}