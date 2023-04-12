[CmdletBinding()]
param (
    [Parameter(Mandatory=$false, Position=0)]
    [int]$TimeInSeconds = 60
)

$logPath = "D:\choes-tools\mem"
$logFile = Join-Path $logPath "$(Get-Date -Format 'yyyyMMddHHmmss')_$env:COMPUTERNAME.log"

# Create log file directory if it does not exist
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

# Log function to write output to console and log file
function Log-Output {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Output
    )
    process {
        Write-Output $Output | Tee-Object -FilePath $logFile -Append
    }
}

# RAM in box
$box = Get-WmiObject Win32_ComputerSystem
$physMB = $box.TotalPhysicalMemory / 1024 / 1024

# leave 512Mb for the OS to survive.
$HEADROOM = 512

$maxRAM = $physMB - $HEADROOM

$progress = 0
$completed = 0
$startDate = Get-Date

Log-Output "=-=-=-=-=-=-=-=-=-= Memory Stress Started: $startDate =-=-=-=-=-=-=-=-=-="
Log-Output "mem_stress - This script will consume all available RAM on the machine"
Log-Output "Starting RAM usage: 0 of $maxRAM (0% Full)"
Log-Output "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

# Calculate size of array to consume all RAM
$arraySize = [int]($maxRAM * 1MB / [char]::size)

# Allocate array to consume all RAM at once
[array]$bigArray = [char[]]::new($arraySize)

# This loop will run for the specified time or until we have consumed all available RAM
$timer = [Diagnostics.Stopwatch]::StartNew()
while ($timer.Elapsed.TotalSeconds -lt $TimeInSeconds -and $bigArray.Length -lt $maxRAM * 1MB) {
    $bigArray = [char[]]::new($bigArray.Length + $arraySize)
    $progress = $bigArray.Length / ($maxRAM * 1MB) * 100
    $completed = [int]$progress
    $statusString = "{0:N2} GB of {1:N2} GB ({2}%) consumed" -f ($bigArray.Length / 1GB), ($maxRAM - $HEADROOM) / 1GB, $completed
    if ($completed % 10 -eq 0) {
        Log-Output $statusString
    }
}

Log-Output "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

# Do a final check of RAM after consuming it all
$ram = $physMB - ($box.FreePhysicalMemory / 1024 / 1024)
$completed = [int]($ram / $maxRAM * 100)
$statusString = "{0:N2} GB of {1:N2} GB ({2}%) consumed" -f ($ram * 1GB), ($maxRAM - $HEADROOM) / 1GB, $completed
Log-Output "FINAL: $statusString"

# Clear the big array to release all consumed memory
Log-Output "Clearing RAM"
$bigArray = $null
[System.GC]::Collect()

$ram = $physMB - ($box.FreePhysicalMemory / 1024 / 1024)
$completed = [int]($ram / $maxRAM
#--------------------------------------------------------------------------------------------------------------------
