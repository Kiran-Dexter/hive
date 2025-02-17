[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [int]$TimeLimit,
    [Parameter(Mandatory=$true)]
    [string]$HostName
)

$LogPath = "D:\tmp\choes-tools\mem\" + (Get-Date -Format "ddMMyy") + $HostName + ".log"

function Log-Output {
    param (
        [Parameter(Mandatory=$true)]
        [string]$LogPath,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logMessage = "$timestamp - $Message`r`n"
    Add-Content $LogPath -Value $logMessage
}

# RAM in box
$box=get-WMIobject Win32_ComputerSystem
$Global:physMB=$box.TotalPhysicalMemory / 1024 /1024

# Create object to get current memory available
$Global:psPerfMEM = new-object System.Diagnostics.PerformanceCounter("Memory","Available Mbytes")
$psPerfMEM.NextValue() | Out-Null

# leave 512Mb for the OS to survive.
$HEADROOM=512

$ram = $physMB - $psPerfMEM.NextValue()
$maxRAM=$physMB - $HEADROOM

$progress = ($ram / $maxRAM) * 100
$completed  = [int]$progress
$StartDate = Get-Date

Log-Output -LogPath $LogPath -Message "=-=-=-=-=-=-=-=-=-=  Memory Stress Started: $StartDate =-=-=-=-=-=-=-=-=-="
Log-Output -LogPath $LogPath -Message "mem_stress - This script will consume all but 512MB of RAM available on the machine"
Log-Output -LogPath $LogPath -Message "Starting consumed RAM: $ram out of $maxRAM ($completed% Full)"
Log-Output -LogPath $LogPath -Message "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

# If you increase the size of the array the GC seems to do quicker cleanups
# Not sure why, but 200MB seems to be the suite spot
$a = "a" * 200MB

# These are the arrays we will create to consume all of the RAM
$growArray = @()
$growArray += $a
$bigArray = @()
$k=0
$lastCompleted = 900

# This loop will continue until we have consumed all of the RAM minus the headroom
while ($ram -lt $maxRAM) {
    $bigArray += ,@($k,$growArray)
    $k += 1
    $growArray += $a
    # Find out how much RAM we are now consuming
    $ram = $physMB - $psPerfMEM.NextValue()
    $progress = ($ram / $maxRAM) * 100
    $completed  = [int]$progress
    $status_string = -join([int]$ram," of ",[int]$maxRAM, "MB ($completed% Complete)")
    # Only show the message when we have a change in percentage
    if ($completed -ne $lastCompleted) {
        Log-Output -LogPath $LogPath -Message $status_string
        $lastCompleted = $completed
    }
    # Check if time limit has been reached
    if ((New-TimeSpan -Start $StartDate).TotalMinutes -gt $TimeLimit) {
        Log-Output -LogPath $LogPath -Message "Time limit of $TimeLimit minutes reached. Exiting script."
        break
    }
}

Log-Output -LogPath $LogPath -Message "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
# Do a final check of RAM after consuming it all

$ram = Get-WmiObject Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory

$available_ram = $ram.FreePhysicalMemory / 1MB

Log-Output -LogPath $LogPath -Message "After consuming all available RAM, the available RAM is $available_ram MB"

Log-Output -LogPath $LogPath -Message "Clearing RAM" and now release it all.

$bigArray.clear()
$growArray.clear()

Log-Output -LogPath $LogPath -Message "RAM has been cleared"

Log-Output -LogPath $LogPath -Message "Exiting script."
