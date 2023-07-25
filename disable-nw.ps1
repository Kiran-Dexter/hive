$LogFilePath = "c:\tmp\network_adapter_log.txt"

# Function to log messages to the log file
function Log-Message {
    param([string]$message)
    Add-Content -Path $LogFilePath -Value "$(Get-Date) - $message"
}

# Function to disable a network adapter
function Disable-NetworkAdapters {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    foreach ($adapter in $adapters) {
        $adapterName = $adapter.Name
        Disable-NetAdapter -Name $adapterName -Confirm:$false
        Log-Message "Adapter '$adapterName' disabled."
    }
}

# Function to enable all network adapters
function Enable-NetworkAdapters {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Disabled' }
    foreach ($adapter in $adapters) {
        $adapterName = $adapter.Name
        Enable-NetAdapter -Name $adapterName
        Log-Message "Adapter '$adapterName' enabled."
    }
}

# Disable all network adapters
Disable-NetworkAdapters

# Wait for 60 seconds
Start-Sleep -Seconds 60

# Enable all network adapters
Enable-NetworkAdapters
