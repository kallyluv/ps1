# OUTPUT
$_dir = (Get-Location).Path.TrimEnd("\")
$outputFile = "$_dir\PCCHECK.txt"

# HEADER
"Executable Path, Last Run Time" | Out-File -FilePath $outputFile
"------------------------------" | Out-File -FilePath $outputFile -Append

# EVENT LOGS
function Get-ExecutionHistoryFromEventLogs {
    $events = Get-WinEvent -LogName Security | Where-Object { $_.Id -eq 4688 }
    
    foreach ($event in $events) {
        # Extract command line info from event details
        $commandLine = $event.Properties[5].Value
        if ($commandLine -match "\S+\.exe") {
            $exePath = $matches[0]
            $timestamp = $event.TimeCreated
            "$exePath, $timestamp" | Out-File -FilePath $outputFile -Append
        }
    }
}

# PREFETCH
function Get-ExecutablesFromPrefetch {
    $prefetchDir = "C:\Windows\Prefetch"
    
    # Check if Prefetch directory exists
    if (Test-Path $prefetchDir) {
        $files = Get-ChildItem -Path $prefetchDir -Filter "*.pf"
        
        foreach ($file in $files) {
            $exeName = $file.Name -replace "\.pf$", ".exe"
            $timestamp = $file.CreationTime
            "$exeName, $timestamp" | Out-File -FilePath $outputFile -Append
        }
    }
}

# EXECUTABLES
function Get-ExecutablesFromMuiCache {
    $keyPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
    $regEntries = Get-ItemProperty -Path $keyPath
    foreach ($entry in $regEntries.PSObject.Properties) {
        $exePath = $entry.Name
        if ($exePath -match "\S+\.exe") {
            "$exePath" | Out-File -FilePath $outputFile -Append
        }
    }
}

# EXECUTABLES + TIMESTAMPS
function Get-ExecutablesFromRegistry {
    $keyPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Recent"
    )
    
    foreach ($keyPath in $keyPaths) {
        if (Test-Path $keyPath) {
            $regEntries = Get-ItemProperty -Path $keyPath
            foreach ($entry in $regEntries.PSObject.Properties) {
                if ($entry.Name -match "^\d+$") {
                    $exePath = $entry.Value
                    if ($exePath -match "\S+\.exe") {
                        "$exePath" | Out-File -FilePath $outputFile -Append
                    }
                }
            }
        }
    }
}

# Start gathering data
Write-Host "Scanning Operating System..."
Write-Host "This process can take up to 5 minutes depending on speeds."
Write-Host ""
"" | Out-File -FilePath $outputFile -Append
"======== REGISTRY SCAN RESULTS ========" | Out-File -FilePath $outputFile -Append
Write-Host "Scanning Explorer Executable Cache..."
Get-ExecutablesFromMuiCache
Write-Host ">> Task Completed!"
Write-Host "Scanning Registry Logs & Executable Timestamps"
Get-ExecutablesFromRegistry
Write-Host ">> Task Completed!"
"=======================================" | Out-File -FilePath $outputFile -Append
"" | Out-File -FilePath $outputFile -Append
"======== OS DEEP SCAN RESULTS ========" | Out-File -FilePath $outputFile -Append
Write-Host "Scanning Windows Event Logs..."
Get-ExecutionHistoryFromEventLogs
Write-Host ">> Task Completed!"
Write-Host "Scanning Windows Prefetch..."
Get-ExecutablesFromPrefetch
Write-Host ">> Task Completed!"
"=======================================" | Out-File -FilePath $outputFile -Append
"" | Out-File -FilePath $outputFile -Append
"PC Check Script Written by @imluvvr" | Out-File -FilePath $outputFile -Append
Write-Host ""

Write-Host "Search completed. Results saved to $outputFile"
