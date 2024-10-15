################################################################################
# .SYNOPSIS
# Updates the disk IDs for disks with duplicate IDs.
#
# .DESCRIPTION
# The Update-DiskID function retrieves all disks and identifies those with duplicate disk IDs.
# If duplicate disk IDs are found, it generates new unique disk IDs for the duplicates.
#
# .EXAMPLE
# PS C:\> Update-DiskID
# This command will update the disk IDs for any disks that have duplicate IDs.
#
# .PARAMETER None
# This function does not take any parameters.
#
# .OUTPUTS
# System.Boolean
# Returns $true if any disk IDs were updated, otherwise returns $false.
#
# .NOTES
# Author: Ryan McCallum (rymccall)
# Version: v0.1
################################################################################

function Update-DiskID() {
    $disks = Get-Disk -ErrorAction Stop
    $criticalDisks = $disks | Where-Object { $_.FriendlyName -ne 'Msft Virtual Disk' }
    $dataDisks = $disks | Where-Object { $_.FriendlyName -eq 'Msft Virtual Disk' }
    $uniqueDiskIDs = @()

    # Get the disk IDs for all disks
    ForEach ($disk in $disks) {
        $command = "select disk $($disk.Number)"
        $command += "`r`n";
        $command += "detail disk";

        $diskpartOutput = $command | diskpart

        $uniqueDiskIDs += [PSCustomObject]@{
            diskNumber       = $disk.Number
            diskFriendlyName = ($diskpartOutput | Select-String 'Disk ID:' -Context 1, 0 | Select-Object -First 1).Context.PreContext
            diskID           = $diskpartOutput | Select-String -Pattern 'Disk ID:\s*(\w+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
        }
    }

    # Check if there are any duplicate disk IDs
    $duplicateDiskIDs = $uniqueDiskIDs | Group-Object -Property diskID | Where-Object { $_.Count -gt 1 }

    if ($duplicateDiskIDs.Count -gt 0) {

        # Generate a new disk ID for each duplicate disk ID
        ForEach ($dupeSet in $duplicateDiskIDs) {
            $targetDisk = $dupeSet.Group | Sort-Object -Property diskNumber -Descending | Select-Object -First 1
            $newDiskID = [System.Guid]::NewGuid().ToString().Replace('-', '').Substring(0, 8)

            $command = "select disk $($targetDisk.diskNumber)"
            $command += "`r`n";
            $command += "uniqueid disk id = $($newDiskID)";
            $command | diskpart | Out-Null
        }
        return $true
    }
    else {
        return $false
    }
}