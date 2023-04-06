#=========================================================
#MEMORY BUSTER
#=========================================================

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [int]$t
)

$LogFilePath = "D:\tmp\chaos-tools\logsmemory.log"
$totalMemory = (Get-WmiObject -Class Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
$loadMemory = $totalMemory

Write-Host "Total memory: $totalMemory bytes"
Write-Host "Load memory: $loadMemory bytes"

Start-Process -FilePath "mdsched.exe" -ArgumentList "/c /m $($loadMemory/1KB)" -NoNewWindow

Start-Sleep -Seconds $t

Start-Process -FilePath "mdsched.exe" -ArgumentList "/c" -NoNewWindow

Write-Host "Memory stress test completed."

if ($LogFilePath) {
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logMessage = "$timestamp - Memory stress test completed. Duration: $t seconds, Load percentage: 100%"
  Add-Content -Path $LogFilePath -Value $logMessage
}

Get-Process -Name mdsched | Foreach-Object { $_.CloseMainWindow() | Out-Null }

#=====================================================================
