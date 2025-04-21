#region PRELOAD
Clear-Host
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
function Test-Administrator {
	$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Administrator)) {
	$scriptUrl = 'https://bit.ly/luvvr-pc-check'
	$cmd = "irm `"$scriptUrl`" | iex"
	$arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"& { $cmd }`""
	Start-Process powershell.exe -ArgumentList $arguments -Verb runAs
	exit
}

#region Global Variables

$global:selectedGame = "None"
$global:storagePath = "$env:USERPROFILE\Documents\PC Scans"
$global:outputFile = $null
$global:outputLines = @{}
$global:foundFiles = @()

#endregion
#region UI Sections

function Show-MainMenu {
	param (
		[string]$ErrorMessage = $null
	)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Windows OS Deep Scan ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Game Selected: $global:selectedGame" -Color Cyan
	Write-HostCenter "Output Path: $global:storagePath" -Color Cyan
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Start Scan" -Color Green
	Write-HostCenter "2) Scan Settings" -Color Green
	Write-HostCenter "3) Open Scans Folder" -Color Green
	Write-HostCenter "4) Exit Program" -Color Green
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		"1" {
			New-OutputFile
			switch ($global:selectedGame) {
				"None" {
					Start-BasicScan
				}
				"Rainbow Six Siege" {
					Start-R6Scan
				}
				Default {
					Start-BasicScan
				}
			}
		}
		"2" {
			Show-ScanSettingsMain
		}
		"3" {
			Start-Process $global:storagePath
		}
		"4" {
			Show-ExitScreen
			Exit
		}
		Default {
			Show-MainMenu -ErrorMessage "That is not a valid option!"
		}
	}
}

function Show-ScanSettingsMain {
	param (
		[string]$ErrorMessage = $null
	)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Scan Settings ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Game Selected: $global:selectedGame" -Color Cyan
	Write-HostCenter "Output Path: $global:storagePath" -Color Cyan
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Select Game" -Color Green
	Write-HostCenter "2) Select Output Path" -Color Green
	Write-HostCenter "3) Back" -Color Green
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		"1" {
			Show-ScanSettingsGameSelect
		}
		"2" {
			$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
			$folderBrowser.Description = "Select a folder"
			$folderBrowser.ShowNewFolderButton = $true
			if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$global:storagePath = $folderBrowser.SelectedPath
			}
			Show-ScanSettingsMain
		}
		"3" {
			Show-MainMenu
		}
		Default {
			Show-ScanSettingsMain -ErrorMessage "That is not a valid option!"
		}
	}
}

function Show-ScanSettingsGameSelect {
	param (
		[string]$ErrorMessage = $null
	)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Scan Settings ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Game Selected: $global:selectedGame" -Color Cyan
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) None" -Color Green
	Write-HostCenter "2) Rainbow Six Siege" -Color Green
	Write-HostCenter "3) Back" -Color Green
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		"1" {
			$global:selectedGame = "None"
		}
		"2" {
			$global:selectedGame = "Rainbow Six Siege"
		}
		"3" {
			Show-ScanSettingsMain
		}
		Default {
			Show-ScanSettingsGameSelect -ErrorMessage "That is not a valid option!"
		}
	}
}

function Show-EndScanScreen {
	Clear-Host
	Write-Host
	Write-HostCenter "======== Scan Complete ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Scan Results Written To: $global:outputFile" -Color Cyan
	Write-Host
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	Write-Host "`n"
	Write-HostCenter "Press any key to continue..." -Color Gray

	Wait-ForInput
}

function Show-ExitScreen {
	Clear-Host
	Write-Host
	Write-HostCenter "======== Windows OS Deep Scan ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Main Developer: @imluvvr on X" -Color Cyan
	Write-HostCenter "Hardware Info Scans: @ScaRMR6 on X" -Color Cyan
	Write-Host
	Write-HostCenter "======== Program Exited ========" -Color DarkRed
	Write-Host
	Start-Sleep -Seconds 4
	Clear-Host
}

#endregion

#region Utility
function Write-HostCenter { 
	param(
		[switch]$Bold,
		[switch]$NoNewline,
		$Message,

		[ConsoleColor]$Color = "White",
		[ConsoleColor]$Background = ($Host.UI.RawUI.BackgroundColor)

	) 

	$originalFg = $Host.UI.RawUI.ForegroundColor
	$originalBg = $Host.UI.RawUI.BackgroundColor

	$Host.UI.RawUI.BackgroundColor = $Background
	$Host.UI.RawUI.ForegroundColor = $Color

	if ($Bold) {
		$esc = [char]27
		$boldOn = "${esc}[1m"
		$reset = "${esc}[0m"
		if ($NoNewline) {
			Write-Host "$boldOn$("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message)$reset" -NoNewline
		}
		else {
			Write-Host "$boldOn$("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message)$reset" 
		}
	}
	else {
		if ($NoNewline) {
			Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message) -NoNewline
		}
		else {
			Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message)
		}
	}
	$Host.UI.RawUI.ForegroundColor = $originalFg
	$Host.UI.RawUI.BackgroundColor = $originalBg
}

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

function New-OutputFile {
	if (-not (Test-Path $global:storagePath)) {
		New-Item -ItemType Directory -Path "$global:storagePath" -Force
	}
	$global:outputFile = "$global:storagePath\pc_check_$(Get-Date -Format 'yyyy-MM-dd-HH-mm-ss').txt"

	if (Test-Path $global:outputFile) {
		Remove-Item $global:outputFile
	}

	$global:outputLines["header"] = @(
		"========================================",
		"PC Name: $env:COMPUTERNAME", 
		"User Name: $env:USERNAME",
		"`nGame Selected: $global:selectedGame", 
		"`nPC Check Started: $(Get-Date -Format 'yyyy-MM-dd @ HH:mm:ss')", 
		"Full Internal File Scan + Hardware Scan", 
		"========================================"
	)
}

function Write-OutputFile {
	$global:outputLines["footer"] = @(
		"`n========================================",
		"Scan Completed: $(Get-Date -Format 'yyyy-MM-dd @ HH:mm:ss')",
		"`nWritten by @imluvvr & @ScaRMR6 on X"
	)

	foreach ($line in $global:outputLines["header"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	if ($global:outputLines.ContainsKey("r6")) {
		foreach ($line in $global:outputLines["r6"]) {
			Add-Content -Path $global:outputFile -Value $line
		}
	}
	
	if ($global:outputLines.ContainsKey("suspicious")) {
		foreach ($line in $global:outputLines["suspicious"]) {
			Add-Content -Path $global:outputFile -Value $line
		}
	}

	foreach ($line in $global:outputLines["registry"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["prefetch"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["sys"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["network"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["device"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["pcie"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["motherboard"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["bios"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["firmware"]) {
		Add-Content -Path $global:outputFile -Value $line
	}

	foreach ($line in $global:outputLines["footer"]) {
		Add-Content -Path $global:outputFile -Value $line
	}
}

function Invoke-EndScan {
	Write-OutputFile
	Show-EndScanScreen

	Invoke-Item -Path $global:outputFile
}

function Get-BaseNameWithoutExe {
	param (
		[string]$InputString,
		[int]$Buffer = 0
	)

	$exeIndex = $InputString.ToLower().IndexOf(".exe")
	if ($exeIndex -ge 0) {
		$InputString = $InputString.Substring(0, $exeIndex + $Buffer)
	}

	$parts = $InputString -split '[\\/]' | Where-Object { $_ -ne '' }
	return $parts[-1]
}

function Show-CustomProgress {
	param (
		[int]$current,
		[int]$total,
		[string]$prefix = "",
		[int]$barLength = 40
	)

	if ($total -eq 0) { $total = 1 } 

	$percent = [math]::Round(($current / $total) * 100)
	$filledLength = [math]::Floor(($current / $total) * $barLength)
    
	$fillChar = '|'
	$emptyChar = '-'

	$bar = ($fillChar * $filledLength).PadRight($barLength, $emptyChar[0])
	$line = "$prefix [$bar] $percent%"

	Write-Host "`r" -NoNewline
	Write-HostCenter "$line" -NoNewline
}

function Test-ContainsValidWord {
	param (
		[string]$name,
		[System.Collections.Generic.HashSet[string]]$wordSet
	)

	for ($i = 0; $i -lt $name.Length; $i++) {
		for ($j = $i + 3; $j -le $name.Length; $j++) {
			$substring = $name.Substring($i, $j - $i)
			if ($wordSet.Contains($substring)) {
				return $true
			}
		}
	}

	return $false
}

function Get-SuspiciousFiles {
	$files = @()
	$fdict = @(
		"fsquirt", "wmplayer", "vslauncher", "discord", "control", "netplwiz", "powershell", "nvcplui", "pickerhost", "chipset", "cleanmgr", "spotify", "steam", "adobe", "ubisoft"
	)
	$falsePositives = @{}
	$adict = @(
		"klar", "lethal", "dma", "bun", "demoncore", "crusader", "client"
	)
	$alwaysFlag = @{}
	foreach ($entry in $fdict) {
		$falsePositives[$entry.ToLower()] = $true
	}
	foreach ($entry in $adict) {
		$alwaysFlag[$entry.ToLower()] = $true
	}

	Write-HostCenter "Downloading Remote Dictionary..." -Color Green

	$dictUrl = "https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt"
	$tempFile = Join-Path $env:TEMP "words_alpha.txt"

	$req = [System.Net.HttpWebRequest]::Create($dictUrl)
	$res = $req.GetResponse()
	$stream = $res.GetResponseStream()
	$totalBytes = $res.ContentLength
	$buffer = New-Object byte[] 8192
	$bytesRead = 0

	$fileStream = [System.IO.File]::Create($tempFile)

	if (-not $fileStream) {
		Write-HostCenter "Failed to create file stream for $destination" -Color DarkRed -Background Red
	}

	do {
		$read = $stream.Read($buffer, 0, $buffer.Length)
		if ($read -gt 0) {
			$fileStream.Write($buffer, 0, $read)
			$bytesRead += $read
			Show-CustomProgress -current $bytesRead -total $totalBytes -prefix "Downloading"
		}
	} while ($read -gt 0)

	$fileStream.Close()
	$stream.Close()
	$res.Close()
	Write-Host ("`r" + (" " * ([console]::WindowWidth - 1)) + "`r") -NoNewline
	Write-Host "`r" -NoNewline
	Write-HostCenter ">> Dictionary Downloaded <<`n`n" -Color Green -NoNewline

	Write-HostCenter "Building Filter Hash..." -Color Green
	$words = ((Get-Content $tempFile) -split "`n") | Sort-Object Length -Descending
	$wordSet = [System.Collections.Generic.HashSet[string]]::new()
	$words | ForEach-Object {
		if ($_.Length -ge 3) { 
			$null = $wordSet.Add($_)
		}
	}
	Write-HostCenter ">> Done! <<`n" -Color Green

	Write-HostCenter "Sifting Through Files..." -Color Green
	foreach ($filename in $global:foundFiles) {
		$nameOnly = Get-BaseNameWithoutExe -InputString $filename.ToLower()

		if ($alwaysFlag.ContainsKey($nameOnly)) {
			$files = , "$filename" + $files
			continue
		}
		if (Test-ContainsValidWord -name $nameOnly -wordSet $wordSet) {
			continue
		}
		if ($falsePositives.ContainsKey($nameOnly)) {
			continue
		}

		if ($nameOnly.Length -lt 6) {
			continue
		}

		$charArray = $nameOnly.ToCharArray()
		$freqs = @{}
		foreach ($c in $charArray) {
			if ($freqs.ContainsKey($c)) {
				$freqs[$c]++
			}
			else {
				$freqs[$c] = 1
			}
		}
		$entropy = 0
		$entropyMin = 1.5
		foreach ($freq in $freqs.Values) {
			$p = $freq / $charArray.Length
			$entropy += -1 * $p * [Math]::Log($p, 2)
		}

		if ($entropy -ge $entropyMin) {
			$files += "$filename"
		}
	}

	Write-HostCenter ">> Found $($files.Count) Suspicious Files <<`n" -Color Green
	
	if ($files.Count -gt 0) {
		$global:outputLines["suspicious"] = @("`n======== SUSPICIOUS FILES ========")
		foreach ($f in $files) {
			$global:outputLines["suspicious"] += $f
		}
	}

	if (Test-Path $tempFile) {
		Write-HostCenter "Cleaning up temporary dictionary file..." -Color Green
		Remove-Item $tempFile -Force
		Write-HostCenter ">> Done! <<`n" -Color Green
	}
}

function Wait-ForInput {
	param (
		[string]$Message = $null,
		[ConsoleColor]$TextColor = "White"
	)

	if ($Message) {
		Write-HostCenter $Message -Color $TextColor
	}
	$read = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
	return ($read.Character)
}
#endregion

#region Scan Functions
# === FUNCTION: Get Execution History from Event Logs ===
function Get-ExecutionHistoryFromEventLogs {
	Write-HostCenter "Scanning Windows Security Event Logs (4688)..." -Color Green -Bold
	try {
		$events = Get-WinEvent -LogName Security -FilterHashtable @{Id = 4688 } -MaxEvents 1000
		foreach ($event in $events) {
			$commandLine = $event.Properties[5].Value
			if ($commandLine -match "\S+\.exe") {
				$exePath = $matches[0]
				$timestamp = $event.TimeCreated
				$global:outputLines["sys"] += "$exePath, $timestamp"
				$global:foundFiles += "$exePath"
			}
		}
	}
 catch {
		$global:outputLines["sys"] += "Failed to read event logs: $_"
	}
	Write-HostCenter ">> Event log scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read Prefetch Folder ===
function Get-ExecutablesFromPrefetch {
	Write-HostCenter "Scanning Windows Prefetch..." -Color Green -Bold
	$prefetchDir = "$($ENV:SystemRoot)\Prefetch"
	if (Test-Path $prefetchDir) {
		Get-ChildItem -Path $prefetchDir -Filter "*.pf" | ForEach-Object {
			$exeName = $_.Name -replace "\.pf$", ""
			$timestamp = $_.CreationTime
			$global:outputLines["prefetch"] += "$exeName, $timestamp"
			$global:foundFiles += "$(Get-BaseNameWithoutExe -InputString $exeName -Buffer 4)"
		}
	}
 else {
		$global:outputLines["prefetch"] += "Prefetch folder not found."
	}
	Write-HostCenter ">> Prefetch scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read MUI Cache Registry ===
function Get-ExecutablesFromMuiCache {
	Write-HostCenter "Scanning MUI Cache Registry..." -Color Green -Bold
	$keyPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache"
	if (Test-Path $keyPath) {
		$entries = Get-ItemProperty -Path $keyPath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				$global:outputLines["registry"] += "$($entry.Name)"
				$global:foundFiles += "$($entry.Name)"
			}
		}
	}
 else {
		$global:outputLines["registry"] += "MuiCache not found."
	}
	Write-HostCenter ">> MUI Cache scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from AppSwitched ===
function Get-AppSwitched {
	Write-HostCenter "Scanning AppSwitched..." -Color Green -Bold
	$keypath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FeatureUsage\AppSwitched"

	if (Test-Path $keypath) {
		$entries = Get-ItemProperty -Path $keypath
		foreach ($entry in $entries.PSObject.Properties) {
			if ($entry.Name -match "\S+\.exe") {
				$global:outputLines["registry"] += "$($entry.Name)"
				$global:foundFiles += "$($entry.Name)"
			}
		}
	}
	else {
		$global:outputLines["registry"] += "Registry path not found: $keypath"
	}
	Write-HostCenter ">> AppSwitched scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from Registry ===
function Get-ExecutablesFromRegistry {
	Write-HostCenter "Scanning Registry for Executables..." -Color Green -Bold
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
					$global:outputLines["registry"] += "$($entry.Value)"
					$global:foundFiles += "$($entry.Value)"
				}
			}
		}
		else {
			$global:outputLines["registry"] += "Registry path not found: $key"
		}
	}
	Write-HostCenter ">> Registry scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Read Executables from Encoded Registry ===
function Get-EncodedExecutablesFromRegistry {
	Write-HostCenter "Scanning Encoded Registry Sectors for Executables..." -Color Green -Bold
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
					$global:outputLines["registry"] += "$($decodedEntry)"
					$global:foundFiles += "$($decodedEntry)"
				}
			}
		}
		else {
			$global:outputLines["registry"] += "Registry path not found: $key"
		}
	}
	Write-HostCenter ">> Encoded Registry scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Open Network Ports ===
function Get-OpenNetworkPorts {
	Write-HostCenter "Scanning Open Network Ports..." -Color Green -Bold
	$global:outputLines["network"] = @("`n======== NETWORK PORT SCAN ========")
	try {
		$netStats = Get-NetTCPConnection | Where-Object { $_.State -eq "Listen" }
		foreach ($conn in $netStats) {
			$local = ":$($conn.LocalPort)"
			$proc = (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName
			$global:outputLines["network"] += "TCP LISTEN - $local - Process: $proc"
		}

		$udpStats = Get-NetUDPEndpoint
		foreach ($conn in $udpStats) {
			$local = ":$($conn.LocalPort)"
			$proc = (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName
			$global:outputLines["network"] += "UDP ENDPOINT - $local - Process: $proc"
		}
	}
 catch {
		$global:outputLines["network"] += "Failed to retrieve port info: $_"
	}
	Write-HostCenter ">> Port scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: DMA-capable Devices ===
function Get-DMADevices {
	Write-HostCenter "Scanning Devices..." -Color Green -Bold
	$global:outputLines["device"] = @("`n======== DEVICE SCAN ========")
	try {
		$devices = Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match "USB|Thunderbolt|1394|DMA" }
		foreach ($dev in $devices) {
			$global:outputLines["device"] += "$($dev.FriendlyName) - $($dev.Class) - $($dev.Status)"
		}
	}
 catch {
		$global:outputLines["device"] += "Failed to check DMA-related devices: $_"
	}
	Write-HostCenter ">> Device scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: PCIe Devices (like GPU) ===
function Get-PCIeDevices {
	Write-HostCenter "Scanning PCIe Devices..." -Color Green -Bold
	$global:outputLines["pcie"] = @("`n======== PCIE SCAN ========")
	try {
		$pcieDevices = Get-PnpDevice -PresentOnly | Where-Object {
			$_.InstanceId -match "^PCI\\" -and ($_.Class -match "Display|System|Net|Media|Storage")
		}

		if ($pcieDevices.Count -eq 0) {
			$global:outputLines["pcie"] += "No PCIe devices detected."
		}
		else {
			foreach ($device in $pcieDevices) {
				$desc = "$($device.FriendlyName) - Class: $($device.Class) - Status: $($device.Status)"
				$global:outputLines["pcie"] += $desc
			}
		}
	}
 catch {
		$global:outputLines["pcie"] += "Failed to scan PCIe devices: $_"
	}
	Write-HostCenter ">> PCIe device scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Recently Closed Applications ===
function Get-RecentlyClosedApps {
	Write-HostCenter "Scanning Recently Closed Applications..." -Color Green -Bold
	$global:outputLines["sys"] += "`n======== RECENTLY CLOSED APPLICATIONS ========"
	try {
		$stoppedEvents = Get-WinEvent -LogName "Microsoft-Windows-WMI-Activity/Operational" -MaxEvents 200 |
		Where-Object { $_.Id -eq 23 -and $_.Message -match "\.exe" }

		if ($stoppedEvents.Count -eq 0) {
			$global:outputLines["sys"] += "No recent application close events found."
		}
		else {
			foreach ($event in $stoppedEvents) {
				$msg = $event.Message
				if ($msg -match "Process\s(.+?\.exe)") {
					$exe = $matches[1]
					$time = $event.TimeCreated
					$global:outputLines["sys"] += "$exe closed at $time"
					$global:foundFiles += "$exe"
				}
			}
		}
	}
 catch {
		$global:outputLines["sys"] += "Failed to read closed app data: $_"
	}
	Write-HostCenter ">> Recently closed app scan complete! <<`n" -Color DarkGreen
}

# === FUNCTION: BIOS & Motherboard Info ===
function Get-BIOSInfo {
	Write-HostCenter "Collecting BIOS Information..." -Color Green -Bold
	$global:outputLines["bios"] = @("`n======== BIOS INFORMATION ========")
	try {
		$bios = Get-CimInstance -ClassName Win32_BIOS
		$global:outputLines["bios"] += "BIOS Manufacturer: $($bios.Manufacturer)"
		$global:outputLines["bios"] += "BIOS Version     : $($bios.SMBIOSBIOSVersion)"
		$global:outputLines["bios"] += "BIOS Release Date: $($bios.ReleaseDate)"
	}
 catch {
		$global:outputLines["bios"] += "Failed to retrieve BIOS info: $_"
	}
	Write-HostCenter ">> BIOS info collected! <<`n" -Color DarkGreen
}

function Get-MotherboardInfo {
	Write-HostCenter "Collecting Motherboard & I/O Information..." -Color Green -Bold
	$global:outputLines["motherboard"] = @("`n======== MOTHERBOARD INFORMATION ========")
	try {
		$board = Get-CimInstance -ClassName Win32_BaseBoard
		$global:outputLines["motherboard"] += "Manufacturer : $($board.Manufacturer)"
		$global:outputLines["motherboard"] += "Product Name : $($board.Product)"
		$global:outputLines["motherboard"] += "Serial Number: $($board.SerialNumber)"
	}
 catch {
		$global:outputLines["motherboard"] += "Failed to retrieve motherboard info: $_"
	}
	Write-HostCenter ">> Motherboard info collected! <<`n" -Color DarkGreen
}

# === FUNCTION: BIOS DMA-Related Settings (via Windows) ===
function Get-FirmwareSecurityState {
	Write-HostCenter "Checking Firmware Information..." -Color Green -Bold
	$global:outputLines["firmware"] = @("`n======== FIRMWARE INFORMATION ========")
	try {
		$secureBoot = Confirm-SecureBootUEFI
		$global:outputLines["firmware"] += "Secure Boot: $(if ($secureBoot) { 'Enabled' } else { 'Disabled' })"
	}
 catch {
		$global:outputLines["firmware"] += "Secure Boot: Unable to determine (BIOS mode or unsupported)"
	}

	try {
		$virt = Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty VirtualizationFirmwareEnabled
		$global:outputLines["firmware"] += "Virtualization Technology (VT-x): $(if ($virt) { 'Enabled' } else { 'Disabled' })"
	}
 catch {
		$global:outputLines["firmware"] += "Virtualization Technology: Could not detect"
	}

	try {
		$tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
		if ($tpm) {
			$global:outputLines["firmware"] += "TPM Version: $($tpm.SpecVersion)"
			$global:outputLines["firmware"] += "TPM Enabled: $($tpm.IsEnabled_InitialValue)"
		}
		else {
			$global:outputLines["firmware"] += "TPM: Not available"
		}
	}
 catch {
		$global:outputLines["firmware"] += "TPM: Unable to query"
	}
	Write-HostCenter ">> Firmware security checks complete! <<`n" -Color DarkGreen
}

# === FUNCTION: Extra Scans
function Get-RainbowSixAccounts {
	$uids = @()
	Write-Host
	Write-HostCenter "Revealing all Rainbow Six Siege Accounts..." -Color Green
	$global:outputLines["r6"] = @("`n======== Rainbow Six Siege Accounts ========")
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
	Write-Host
	foreach ($uid in $uids) {
		Start-Process "https://stats.cc/siege/$uid"
		$global:outputLines["r6"] += "$uid"
		Write-HostCenter "Found $uid" -Color DarkGreen
	}
	Write-Host
	Write-HostCenter ">> Rainbow Six Siege Accounts Revealed! <<`n" -Color DarkGreen
}
#endregion

#region Execution Functions

function Start-BaseScan {
	Clear-Host
	Write-Host
	Write-HostCenter "Starting PC Scans..." -Color Magenta
	Start-Sleep -Seconds 1
	Clear-Host

	Write-Host
	Write-HostCenter "Starting PC scan -> Executables Data...`n" -Color Magenta
	$global:outputLines["registry"] = @("`n======== REGISTRY & CACHE SCAN ========")

	Get-ExecutablesFromMuiCache
	Get-ExecutablesFromRegistry
	Get-EncodedExecutablesFromRegistry
	Get-AppSwitched

	$global:outputLines["prefetch"] = @("`n======== PREFETCH SCAN ========")

	Get-ExecutablesFromPrefetch

	$global:outputLines["sys"] = @("`n======== SYSTEM EVENT SCAN ========")

	Get-ExecutionHistoryFromEventLogs
	Get-RecentlyClosedApps

	Start-Sleep -Milliseconds 800
	Clear-Host

	Write-Host
	Write-HostCenter "Starting Deep PC scan -> Hardware Scan`n" -Color Magenta

	Get-OpenNetworkPorts
	Get-DMADevices
	Get-PCIeDevices
	Get-BIOSInfo
	Get-MotherboardInfo
	Get-FirmwareSecurityState

	Clear-Host
	Write-Host
	Write-HostCenter "Scanning Found Files for Suspicious Activity" -Color Magenta
	Write-HostCenter "Note: This Could Take A While...`n" -Color Gray
	Get-SuspiciousFiles

	Start-Sleep -Milliseconds 800
}

function Start-BasicScan {
	Start-BaseScan
	Invoke-EndScan
}

function Start-R6Scan {
	Start-BaseScan
	Get-RainbowSixAccounts
	Invoke-EndScan
}

#endregion

#region Run
do {
	Clear-Host
	Show-MainMenu
} while ($true)
#endregion