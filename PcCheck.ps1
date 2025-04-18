# === PRELOAD ===
Clear-Host
$ProgressPreference = 'SilentlyContinue'
function Test-Administrator {
	$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
	$argString = $args -join " "
	Write-Host "$argString"
	$cmd = "iex `"& { `$(irm `"https://bit.ly/luvvr-pc-check`") } $argString`""
	$arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $cmd }"
	Start-Process powershell.exe -ArgumentList $arguments -Verb runAs
	exit
}

$extras = $args;

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

# === FUNCTION: Centered Write-Host
function Write-HostCenter { 
	param(
		$Message,

		[ConsoleColor]$Color = "White",
		[ConsoleColor]$Background = ($Host.UI.RawUI.BackgroundColor),

		[bool]$Bold = $false
	) 

	$originalFg = $Host.UI.RawUI.ForegroundColor
	$originalBg = $Host.UI.RawUI.BackgroundColor

	$Host.UI.RawUI.BackgroundColor = $Background
	$Host.UI.RawUI.ForegroundColor = $Color

	if ($Bold) {
		$esc = [char]27
		$boldOn = "${esc}[1m"
		$reset = "${esc}[0m"
		Write-Host "$boldOn$("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message)$reset" 
	}
	else {
		Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message) 
	}
	$Host.UI.RawUI.ForegroundColor = $originalFg
	$Host.UI.RawUI.BackgroundColor = $originalBg
}

# === FUNCTION: Resize Window
function Set-WindowSize {
	param (
		[Parameter(Mandatory = $true)]
		[int]$Width,

		[Parameter(Mandatory = $true)]
		[int]$Height
	)

	try {
		$console = $Host.UI.RawUI
		# Adjust buffer size if needed
		$bufferSize = $console.BufferSize
		$bufferSize.Width = $Width
		$bufferSize.Height = $Height
		$console.BufferSize = $bufferSize

		# Set window size
		$newSize = $console.WindowSize
		$newSize.Width = $Width
		$newSize.Height = $Height
		$console.WindowSize = $newSize
	}
	catch {
	}
}

# === FUNCTION: Decode ROT13 Strings ===
function Convert-ROT13 {
	param (
		[string]$InputString
	)

	return ($InputString.ToCharArray() | ForEach-Object {
			$c = [int][char]$_
			if ($c -ge 65 -and $c -le 90) {
				[char](65 + (($c - 65 + 13) % 26))
			}
			elseif ($c -ge 97 -and $c -le 122) {
				[char](97 + (($c - 97 + 13) % 26))
			}
			else {
				$_
			}
		}) -join ''
}

# === FUNCTION: Get Execution History from Event Logs ===
function Get-ExecutionHistoryFromEventLogs {
	Write-HostCenter "Scanning Windows Security Event Logs (4688)..." -Color Green -Bold $true
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
	Write-HostCenter ">> Event log scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read Prefetch Folder ===
function Get-ExecutablesFromPrefetch {
	Write-HostCenter "Scanning Windows Prefetch..." -Color Green -Bold $true
	$prefetchDir = "$($ENV:SystemRoot)\Prefetch"
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
	Write-HostCenter ">> Prefetch scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read MUI Cache Registry ===
function Get-ExecutablesFromMuiCache {
	Write-HostCenter "Scanning MUI Cache Registry..." -Color Green -Bold $true
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
	Write-HostCenter ">> MUI Cache scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from AppSwitched ===
function Get-AppSwitched {
	Write-HostCenter "Scanning AppSwitched..." -Color Green -Bold $true
	$keypath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched"

	if (Test-Path $keypath) {
		$entries = Get-ItemProperty -Path $keypath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				Add-Content -Path $outputFile -Value "$($entry.Name)"
			}
		}
	}
	else {
		Add-Content -Path $outputFile -Value "Registry path not found: $keypath"
	}
	Write-HostCenter ">> AppSwitched scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from Registry ===
function Get-ExecutablesFromRegistry {
	Write-HostCenter "Scanning Registry for Executables..." -Color Green -Bold $true
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
	Write-HostCenter ">> Registry scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from Encoded Registry ===
function Get-EncodedExecutablesFromRegistry {
	Write-HostCenter "Scanning Encoded Registry Sectors for Executables..." -Color Green -Bold $true
	$keyPaths = @(
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{CEBFF5CD-ACE2-4F4F-9178-9926F41749EA}\Count",
		"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{F4E57C4B-2036-45F0-A9AB-443BCFE33D9F}\Count"
	)

	foreach ($key in $keyPaths) {
		if (Test-Path $key) {
			$entries = Get-ItemProperty -Path $key
			foreach ($entry in $entries.PSObject.Properties) {
				$decodedEntry = Convert-ROT13 -InputString "$($entry.Name)"
				if ($decodedEntry -match "\S+\.exe") {
					Add-Content -Path $outputFile -Value "$($decodedEntry)"
				}
			}
		}
		else {
			Add-Content -Path $outputFile -Value "Registry path not found: $key"
		}
	}
	Write-HostCenter ">> Encoded Registry scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Open Network Ports ===
function Get-OpenNetworkPorts {
	Write-HostCenter "Scanning Open Network Ports..." -Color Green -Bold $true
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
	Write-HostCenter ">> Port scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: DMA-capable Devices ===
function Get-DMADevices {
	Write-HostCenter "Scanning Devices..." -Color Green -Bold $true
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
	Write-HostCenter ">> Device scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: PCIe Devices (like GPU) ===
function Get-PCIeDevices {
	Write-HostCenter "Scanning PCIe Devices..." -Color Green -Bold $true
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
	Write-HostCenter ">> PCIe device scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Recently Closed Applications ===
function Get-RecentlyClosedApps {
	Write-HostCenter "Scanning Recently Closed Applications..." -Color Green -Bold $true
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
	Write-HostCenter ">> Recently closed app scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: BIOS & Motherboard Info ===
function Get-BIOSInfo {
	Write-HostCenter "Collecting BIOS Information..." -Color Green -Bold $true
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
	Write-HostCenter ">> BIOS info collected! <<`n" -Color DarkGreen
}

function Get-MotherboardInfo {
	Write-HostCenter "Collecting Motherboard & I/O Information..." -Color Green -Bold $true
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
	Write-HostCenter ">> Motherboard info collected! <<`n" -Color DarkGreen
}

# === FUNCTION: BIOS DMA-Related Settings (via Windows) ===
function Get-FirmwareSecurityState {
	Write-HostCenter "Checking Firmware Information..." -Color Green -Bold $true
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
	Write-HostCenter ">> Firmware security checks complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Extra Scans
function Get-ExtraScans {
	foreach ($g in $extras) {
		switch ($g.ToString().ToLower()) {
			"r6" {
				$uids = @()
				Write-Host ""
				Write-HostCenter "Revealing all Rainbow Six Siege Accounts..." -Color Green
				$folders = @(
					"C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\savegames",
					"$($ENV:LOCALAPPDATA)\Ubisoft Game Launcher\spool"
				)
				foreach ($folder in $folders) {
					if (Test-Path "$folder") {
						Get-ChildItem -Path $folder | ForEach-Object {
							$uids += $_.Name
						}
					}
				}
				$uids = $uids | Select-Object -Unique
				Write-Host ""
				foreach ($uid in $uids) {
					Start-Process "https://stats.cc/siege/$uid"
					Write-HostCenter "Found $uid" -Color DarkGreen
				}
				Write-Host ""
				Write-HostCenter ">> Rainbow Six Siege Accounts Revealed! <<`n" -Color DarkGreen
			}
		}
	}
}

# === RUN ALL CHECKS ===
Write-Host ""
Write-HostCenter "======== OS Deep Scan Written by @imluvvr & @ScaRMR6 on X ========" -Color Magenta
Write-Host ""
Write-HostCenter "Starting PC Scans..." -Color Magenta
Start-Sleep -Seconds 3
Clear-Host

Write-Host ""
Write-HostCenter "Starting PC scan -> Executables Data...`n" -Color Magenta
Add-Content -Path $outputFile -Value "`n======== REGISTRY & CACHE SCAN ========"
Get-ExecutablesFromMuiCache
Get-ExecutablesFromRegistry
Get-EncodedExecutablesFromRegistry
Get-AppSwitched

Add-Content -Path $outputFile -Value "`n======== PREFETCH SCAN ========"
Get-ExecutablesFromPrefetch

Add-Content -Path $outputFile -Value "`n======== SYSTEM EVENT SCAN ========"
Get-ExecutionHistoryFromEventLogs
Get-RecentlyClosedApps
Start-Sleep -Milliseconds 800
Clear-Host

Write-Host ""
Write-HostCenter "Starting Deep PC scan -> Hardware Scan`n" -Color Magenta
Get-OpenNetworkPorts
Get-DMADevices
Get-PCIeDevices
Get-BIOSInfo
Get-MotherboardInfo
Get-FirmwareSecurityState

Add-Content -Path $outputFile -Value "`n========================================"
Add-Content -Path $outputFile -Value "Scan Completed: $(Get-Date -Format 'yyyy-MM-dd @ HH:mm:ss')"
Add-Content -Path $outputFile -Value "`nWritten by @imluvvr & @ScaRMR6 on X"
Start-Sleep -Milliseconds 800
Clear-Host

Write-Host ""
Write-HostCenter "======== Running All Extra Checks ========" -Color Magenta
Write-Host ""
Get-ExtraScans
Start-Sleep -Seconds 2

Write-Host ""
Write-HostCenter "======== OS Deep Scan Written by @imluvvr & @ScaRMR6 on X ========" -Color Magenta
Write-Host ""
Write-HostCenter "PC Scans Complete!" -Color Magenta
Start-Sleep -Milliseconds 2500

Clear-Host
Invoke-Item -Path $outputFile
Exit
