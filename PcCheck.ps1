# === PRELOAD ===
Clear-Host
$ProgressPreference = 'SilentlyContinue'
function Test-Administrator {
	$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
	$cmd = "irm `"https://bit.ly/luvvr-pc-check`" | iex"
	$arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $cmd } | pause"
	Start-Process powershell.exe -ArgumentList $arguments -Verb runAs
	exit
}

# === SETUP ===
$storagePath = "$env:USERPROFILE\Documents\PC Scans"
if (-not (Test-Path $storagePath)) {
	New-Item -ItemType Directory -Path "$storagePath" -Force
}
$outputFile = "$storagePath\pc_check_$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').txt"

if (Test-Path $outputFile) {
	Remove-Item $outputFile
}

Add-Content -Path $outputFile -Value "========================================"
Add-Content -Path $outputFile -Value "PC Name: $env:COMPUTERNAME"
Add-Content -Path $outputFile -Value "User Name: $env:USERNAME"
Add-Content -Path $outputFile -Value "`nPC Check Started: $(Get-Date -Format 'yyyy-MM-dd @ HH:mm:ss')"
Add-Content -Path $outputFile -Value "Full Internal File Scan + Hardware Scan"
Add-Content -Path $outputFile -Value "========================================"

# === FUNCTION: Get Execution History from Event Logs ===
function Get-ExecutionHistoryFromEventLogs {
	Write-Host "Scanning Windows Security Event Logs (4688)..."
	try {
		$events = Get-WinEvent -LogName Security -FilterHashtable @{Id = 4688 } -MaxEvents 1000
		foreach ($event in $events) {
			$commandLine = $event.Properties[5].Value
			if ($commandLine -match "\S+\.exe") {
				$exePath = $matches[0]
				$timestamp = $event.TimeCreated
				Add-Content -Path $outputFile -Value "$exePath, $timestamp"
			}
		}
	}
 catch {
		Add-Content -Path $outputFile -Value "Failed to read event logs: $_"
	}
	Write-Host ">> Event log scan complete!`n"
}

# === FUNCTION: Read Prefetch Folder ===
function Get-ExecutablesFromPrefetch {
	Write-Host "Scanning Windows Prefetch..."
	$prefetchDir = "C:\Windows\Prefetch"
	if (Test-Path $prefetchDir) {
		Get-ChildItem -Path $prefetchDir -Filter "*.pf" | ForEach-Object {
			$exeName = $_.Name -replace "\.pf$", ""
			$timestamp = $_.CreationTime
			Add-Content -Path $outputFile -Value "$exeName, $timestamp"
		}
	}
 else {
		Add-Content -Path $outputFile -Value "Prefetch folder not found."
	}
	Write-Host ">> Prefetch scan complete!`n"
}

# === FUNCTION: Read MUI Cache Registry ===
function Get-ExecutablesFromMuiCache {
	Write-Host "Scanning MUI Cache Registry..."
	$keyPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
	if (Test-Path $keyPath) {
		$entries = Get-ItemProperty -Path $keyPath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				Add-Content -Path $outputFile -Value "$($entry.Name)"
			}
		}
	}
 else {
		Add-Content -Path $outputFile -Value "MuiCache not found."
	}
	Write-Host ">> MUI Cache scan complete!`n"
}

# === FUNCTION: Read Executables from Registry ===
function Get-ExecutablesFromRegistry {
	Write-Host "Scanning Registry for Executables..."
	$keyPaths = @(
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
		"HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU",
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Recent"
	)

	foreach ($key in $keyPaths) {
		if (Test-Path $key) {
			$entries = Get-ItemProperty -Path $key
			foreach ($entry in $entries.PSObject.Properties) {
				if ($entry.Value -match "\S+\.exe") {
					Add-Content -Path $outputFile -Value "$($entry.Value)"
				}
			}
		}
		else {
			Add-Content -Path $outputFile -Value "Registry path not found: $key"
		}
	}
	Write-Host ">> Registry scan complete!`n"
}

# === FUNCTION: Open Network Ports ===
function Get-OpenNetworkPorts {
	Write-Host "Scanning Open Network Ports..."
	Add-Content -Path $outputFile -Value "`n======== NETWORK PORT SCAN ========"
	try {
		$netStats = Get-NetTCPConnection | Where-Object { $_.State -eq "Listen" }
		foreach ($conn in $netStats) {
			$local = ":$($conn.LocalPort)"
			$proc = (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName
			Add-Content -Path $outputFile -Value "TCP LISTEN - $local - Process: $proc"
		}

		$udpStats = Get-NetUDPEndpoint
		foreach ($conn in $udpStats) {
			$local = ":$($conn.LocalPort)"
			$proc = (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName
			Add-Content -Path $outputFile -Value "UDP ENDPOINT - $local - Process: $proc"
		}
	}
 catch {
		Add-Content -Path $outputFile -Value "Failed to retrieve port info: $_"
	}
	Write-Host ">> Port scan complete!`n"
}

# === FUNCTION: DMA-capable Devices ===
function Get-DMADevices {
	Write-Host "Scanning Devices..."
	Add-Content -Path $outputFile -Value "`n======== DEVICE SCAN ========"
	try {
		$devices = Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match "USB|Thunderbolt|1394|DMA" }
		foreach ($dev in $devices) {
			Add-Content -Path $outputFile -Value "$($dev.FriendlyName) - $($dev.Class) - $($dev.Status)"
		}
	}
 catch {
		Add-Content -Path $outputFile -Value "Failed to check DMA-related devices: $_"
	}
	Write-Host ">> Device scan complete!`n"
}

# === FUNCTION: PCIe Devices (like GPU) ===
function Get-PCIeDevices {
	Write-Host "Scanning PCIe Devices..."
	Add-Content -Path $outputFile -Value "`n======== PCIE SCAN ========"
	try {
		$pcieDevices = Get-PnpDevice -PresentOnly | Where-Object {
			$_.InstanceId -match "^PCI\\" -and ($_.Class -match "Display|System|Net|Media|Storage")
		}

		if ($pcieDevices.Count -eq 0) {
			Add-Content -Path $outputFile -Value "No PCIe devices detected."
		}
		else {
			foreach ($device in $pcieDevices) {
				$desc = "$($device.FriendlyName) - Class: $($device.Class) - Status: $($device.Status)"
				Add-Content -Path $outputFile -Value $desc
			}
		}
	}
 catch {
		Add-Content -Path $outputFile -Value "Failed to scan PCIe devices: $_"
	}
	Write-Host ">> PCIe device scan complete!`n"
}

# === FUNCTION: Recently Closed Applications ===
function Get-RecentlyClosedApps {
	Write-Host "Scanning Recently Closed Applications..."
	Add-Content -Path $outputFile -Value "`n======== RECENTLY CLOSED APPLICATIONS ========"
	try {
		$stoppedEvents = Get-WinEvent -LogName "Microsoft-Windows-WMI-Activity/Operational" -MaxEvents 200 |
		Where-Object { $_.Id -eq 23 -and $_.Message -match "\.exe" }

		if ($stoppedEvents.Count -eq 0) {
			Add-Content -Path $outputFile -Value "No recent application close events found."
		}
		else {
			foreach ($event in $stoppedEvents) {
				$msg = $event.Message
				if ($msg -match "Process\s(.+?\.exe)") {
					$exe = $matches[1]
					$time = $event.TimeCreated
					Add-Content -Path $outputFile -Value "$exe closed at $time"
				}
			}
		}
	}
 catch {
		Add-Content -Path $outputFile -Value "Failed to read closed app data: $_"
	}
	Write-Host ">> Recently closed app scan complete!`n"
}

# === FUNCTION: BIOS & Motherboard Info ===
function Get-BIOSInfo {
	Write-Host "Collecting BIOS Information..."
	Add-Content -Path $outputFile -Value "`n======== BIOS INFORMATION ========"
	try {
		$bios = Get-CimInstance -ClassName Win32_BIOS
		Add-Content -Path $outputFile -Value "BIOS Manufacturer: $($bios.Manufacturer)"
		Add-Content -Path $outputFile -Value "BIOS Version     : $($bios.SMBIOSBIOSVersion)"
		Add-Content -Path $outputFile -Value "BIOS Release Date: $($bios.ReleaseDate)"
	}
 catch {
		Add-Content -Path $outputFile -Value "Failed to retrieve BIOS info: $_"
	}
	Write-Host ">> BIOS info collected!`n"
}

function Get-MotherboardInfo {
	Write-Host "Collecting Motherboard & I/O Information..."
	Add-Content -Path $outputFile -Value "`n======== MOTHERBOARD INFORMATION ========"
	try {
		$board = Get-CimInstance -ClassName Win32_BaseBoard
		Add-Content -Path $outputFile -Value "Manufacturer : $($board.Manufacturer)"
		Add-Content -Path $outputFile -Value "Product Name : $($board.Product)"
		Add-Content -Path $outputFile -Value "Serial Number: $($board.SerialNumber)"
	}
 catch {
		Add-Content -Path $outputFile -Value "Failed to retrieve motherboard info: $_"
	}
	Write-Host ">> Motherboard info collected!`n"
}

# === FUNCTION: BIOS DMA-Related Settings (via Windows) ===
function Get-FirmwareSecurityState {
	Write-Host "Checking Firmware Information..."
	Add-Content -Path $outputFile -Value "`n======== FIRMWARE INFORMATION ========"
	try {
		$secureBoot = Confirm-SecureBootUEFI
		Add-Content -Path $outputFile -Value "Secure Boot: $(if ($secureBoot) { 'Enabled' } else { 'Disabled' })"
	}
 catch {
		Add-Content -Path $outputFile -Value "Secure Boot: Unable to determine (BIOS mode or unsupported)"
	}

	try {
		$virt = Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty VirtualizationFirmwareEnabled
		Add-Content -Path $outputFile -Value "Virtualization Technology (VT-x): $(if ($virt) { 'Enabled' } else { 'Disabled' })"
	}
 catch {
		Add-Content -Path $outputFile -Value "Virtualization Technology: Could not detect"
	}

	try {
		$tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
		if ($tpm) {
			Add-Content -Path $outputFile -Value "TPM Version: $($tpm.SpecVersion)"
			Add-Content -Path $outputFile -Value "TPM Enabled: $($tpm.IsEnabled_InitialValue)"
		}
		else {
			Add-Content -Path $outputFile -Value "TPM: Not available"
		}
	}
 catch {
		Add-Content -Path $outputFile -Value "TPM: Unable to query"
	}
	Write-Host ">> Firmware security checks complete!`n"
}

# === DISCORD WEBHOOK HANDLING ===
$webhooks = @(
	"https://discord.com/api/webhooks/1359737424871162029/rvZQsCRDL6-_-iZUEjfJSs-PJlfXeh-qW2PckJsytD8aEUNrn-JvCEFJUdnlRodU5Fpr"
)
function Send-DiscordWebhook {
	$boundary = [System.Guid]::NewGuid().ToString()
	$LF = "`r`n"

	$fileName = [System.IO.Path]::GetFileName($outputFile)
	$fileBytes = [System.IO.File]::ReadAllBytes($outputFile)
	$fileContent = [System.Text.Encoding]::ASCII.GetString($fileBytes)

	$bodyLines = @()
	$bodyLines += "--$boundary"
	$bodyLines += "Content-Disposition: form-data; name=`"file1`"; filename=`"$fileName`""
	$bodyLines += "Content-Type: text/plain$LF"
	$bodyLines += $fileContent
	$bodyLines += "--$boundary--$LF"

	$body = $bodyLines -join $LF
	$bodyBytes = [System.Text.Encoding]::ASCII.GetBytes($body)

	$headers = @{
		"Content-Type" = "multipart/form-data; boundary=$boundary"
	}

	foreach ($url in $webhooks) {
		$ProgressPreference = 'SilentlyContinue'
		Invoke-WebRequest -Uri $url -Method Post -Body $bodyBytes -Headers $headers
	}
}

# === RUN ALL CHECKS ===
Write-Host "`n======== OS Deep Scan Written by @imluvvr & @ScaRMR6 on X ========"
Write-Host "`n                    Starting PC Scans..."
Start-Sleep -Seconds 4
Clear-Host

Write-Host "`n[INFO] Starting PC scan -> Executables Data...`n"
Add-Content -Path $outputFile -Value "`n======== REGISTRY & CACHE SCAN ========"
Get-ExecutablesFromMuiCache
Get-ExecutablesFromRegistry

Add-Content -Path $outputFile -Value "`n======== PREFETCH SCAN ========"
Get-ExecutablesFromPrefetch

Add-Content -Path $outputFile -Value "`n======== SYSTEM EVENT SCAN ========"
Get-ExecutionHistoryFromEventLogs
Get-RecentlyClosedApps
Start-Sleep -Milliseconds 2500
Clear-Host


Write-Host "`n[INFO] Starting Deep PC scan -> Hardware Scan`n"
Get-OpenNetworkPorts
Get-DMADevices
Get-PCIeDevices
Get-BIOSInfo
Get-MotherboardInfo
Get-FirmwareSecurityState

Add-Content -Path $outputFile -Value "`n========================================"
Add-Content -Path $outputFile -Value "Scan Completed: $(Get-Date -Format 'yyyy-MM-dd @ HH:mm:ss')"
Add-Content -Path $outputFile -Value "`nWritten by @imluvvr & @ScaRMR6 on X"
Send-DiscordWebhook
Clear-Host

Write-Host "`n======== OS Deep Scan Written by @imluvvr & @ScaRMR6 on X ========"
Write-Host "`n                   PC Scans Complete!"
Start-Sleep -Milliseconds 2500

Invoke-Item -Path $outputFile
Exit
