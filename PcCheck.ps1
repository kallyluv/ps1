#region PRELOAD
Clear-Host
$ProgressPreference = 'SilentlyContinue'
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

Add-Type -AssemblyName System.Windows.Forms
#region Global Variables

$global:selectedGame = "None"
$global:storagePath = "$env:USERPROFILE\Documents\PC Scans"
$global:outputFile = $null
$global:outputLines = @{}
$global:foundFiles = @()
$global:sqlite3 = $null
$global:sqlite3dir = $null
$global:gameSupport = [PSCustomObject]@{
	Full    = @(
		"Rainbow Six Siege"
	)
	Testing = @(
		"Counter Strike"
	)
	Minimal = @(
		"Valorant",
		"Fortnite", 
		"Call of Duty: Black Ops 6", 
		"FiveM", 
		"Escape from Tarkov", 
		"Apex Legends"
	)
	Soon    = @(
		"Counter Strike",
		"Apex Legends"
	)
}

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
	Write-SelectedGame -HideType
	Write-HostCenter "Output Path: $global:storagePath" -Color DarkCyan
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Start Scan" -Color DarkGreen
	Write-HostCenter "2) Scan Settings" -Color DarkGreen
	Write-HostCenter "3) Open Scans Folder" -Color DarkGreen
	Write-Host
	Write-HostCenter "Esc) Exit Program" -Color DarkGreen
	Write-Host "`n"
	if ($global:gameSupport.Testing.Contains($global:selectedGame)) {
		Write-HostCenter "- $global:selectedGame Support is in Testing -" -Color Yellow
		if ($global:gameSupport.Soon.Contains($global:selectedGame)) {
			Write-HostCenter "- Full Support Coming Soon... -" -Color Yellow
		}
		Write-Host "`n"
	}
	elseif ($global:gameSupport.Minimal.Contains($global:selectedGame)) {
		Write-HostCenter "- Support is Minimal for $global:selectedGame -" -Color Red
		Write-HostCenter "- Selecting it will result in little to no differences in Scan Results -" -Color Red
		Write-Host "`n"
	}
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		49 {
			New-OutputFile
			switch ($global:selectedGame) {
				"None" {
					if (Show-ConfirmNoGameScan) { Start-BasicScan }
				}
				Default {
					Start-GameScan
				}
			}
		}
		50 {
			Show-ScanSettingsMain
		}
		51 {
			Start-Process $global:storagePath
		}
		27 {
			Show-ExitScreen
			Exit
		}
		Default {
			Show-MainMenu -ErrorMessage "That is not a valid option!"
		}
	}
}

function Show-ConfirmNoGameScan {
	param (
		[string]$ErrorMessage = $null
	)

	Clear-Host
	Write-Host
	Write-HostCenter "======== Confirmation Prompt ========" -Color DarkRed
	Write-Host
	Write-HostCenter "You have not selected a game!" -Color DarkCyan
	Write-HostCenter "Are you sure you want to start the scan?" -Color DarkCyan
	Write-Host
	Write-HostCenter "1) Yes" -Color DarkGreen
	Write-HostCenter "2) No " -Color DarkGreen
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		49 {
			return $true
		}
		50 {
			return $false
		}
		Default {
			Show-ConfirmNoGameScan -ErrorMessage "That is not a valid option!"
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
	Write-SelectedGame
	Write-HostCenter "Output Path: $global:storagePath" -Color DarkCyan
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Select Game" -Color DarkGreen
	Write-HostCenter "2) Select Output Path" -Color DarkGreen
	Write-Host
	Write-HostCenter "Esc) Back" -Color DarkGreen
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		49	{ Show-ScanSettingsGameSelect }
		50	{
			$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
			$folderBrowser.Description = "Select a folder"
			$folderBrowser.ShowNewFolderButton = $true
			if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$global:storagePath = $folderBrowser.SelectedPath
			}
			Show-ScanSettingsMain
		}
		27	{ Show-MainMenu }
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
	Write-SelectedGame
	Write-Host
	if ($ErrorMessage) {
		Write-HostCenter "$ErrorMessage" -Color Red
		Write-Host
	}
	Write-HostCenter "1) Rainbow Six Siege" -Color DarkGreen
	Write-HostCenter "2) Counter Strike" -Color DarkGreen
	Write-HostCenter "3) Call of Duty: Black Ops 6" -Color DarkGreen
	Write-HostCenter "4) Fortnite" -Color DarkGreen
	Write-HostCenter "5) FiveM" -Color DarkGreen
	Write-HostCenter "6) Escape from Tarkov" -Color DarkGreen
	Write-HostCenter "7) Marvel Rivals" -Color DarkGreen
	Write-HostCenter "8) Valorant" -Color DarkGreen
	Write-HostCenter "9) Apex Legends" -Color DarkGreen
	Write-HostCenter "0) None" -Color DarkGreen
	Write-Host
	Write-HostCenter "Esc) Back" -Color DarkGreen
	Write-Host "`n"
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	$selection = Wait-ForInput
	switch ($selection) {
		48	{ $global:selectedGame = "None" }
		49	{ $global:selectedGame = "Rainbow Six Siege" }
		50	{ $global:selectedGame = "Counter Strike" }
		51	{ $global:selectedGame = "Call of Duty: Black Ops 6" }
		52	{ $global:selectedGame = "Fortnite" }
		53	{ $global:selectedGame = "FiveM" }
		54	{ $global:selectedGame = "Escape from Tarkov" }
		55	{ $global:selectedGame = "Marvel Rivals" }
		56	{ $global:selectedGame = "Valorant" }
		57	{ $global:selectedGame = "Apex Legends" }
		27	{ Show-ScanSettingsMain }
		Default	{ Show-ScanSettingsGameSelect -ErrorMessage "That is not a valid option!" }
	}
	Show-ScanSettingsMain
}

function Show-EndScanScreen {
	Clear-Host
	Write-Host
	Write-HostCenter "======== Scan Complete ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Scan Results Written To: $global:outputFile" -Color DarkCyan
	Write-Host
	Write-HostCenter "======== Written by @imluvvr & @ScaRMR6 on X ========" -Color DarkRed

	Write-Host "`n"
	Write-HostCenter "Press any key to continue..." -Color DarkGray

	Wait-ForInput
}

function Show-ExitScreen {
	Clear-Host
	Write-Host
	Write-HostCenter "======== Windows OS Deep Scan ========" -Color DarkRed
	Write-Host
	Write-HostCenter "Main Developer: @imluvvr on X" -Color DarkCyan
	Write-HostCenter "Hardware Info Scans: @ScaRMR6 on X" -Color DarkCyan
	Write-Host
	Write-HostCenter "======== Program Exited ========" -Color DarkRed
	Write-Host
	Start-Sleep -Seconds 4
	Clear-Host
}

#endregion

#region Utility
function Clear-CurrentLine {
	Write-Host ("`r" + (" " * ([console]::WindowWidth - 1)) + "`r") -NoNewline
}

function Write-HostCenter { 
	param(
		[switch]$Bold,
		[switch]$NoNewline,
		$Message,

		[int]$Buffer = 0,

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
			Write-Host "$boldOn$("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))), $Message)$reset" -NoNewline
		}
		else {
			Write-Host "$boldOn$("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))), $Message)$reset" 
		}
	}
	else {
		if ($NoNewline) {
			Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))), $Message) -NoNewline
		}
		else {
			Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor(($Message.Length + $Buffer) / 2)))), $Message)
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

function Write-SelectedGame {
	param (
		[switch]$HideType
	)

	$extraBuffer = 0
	switch ($true) {
		($global:gameSupport.Full.Contains($global:selectedGame)) {
			Write-HostCenter "Game Selected: $global:selectedGame" -Color Green -NoNewline
		}
		($global:gameSupport.Testing.Contains($global:selectedGame)) {
			if (-not $HideType) {
				Write-HostCenter "Game Selected: $global:selectedGame (Testing)" -Color Yellow -NoNewline
				$extraBuffer += (" (Testing)".Length)
			}
			else {
				Write-HostCenter "Game Selected: $global:selectedGame" -Color Yellow -NoNewline
			}
		}
		($global:gameSupport.Minimal.Contains($global:selectedGame)) {
			if (-not $HideType) {
				Write-HostCenter "Game Selected: $global:selectedGame (Minimal)" -Color Red -NoNewline
				$extraBuffer += (" (Minimal)".Length)
			}
			else {
				Write-HostCenter "Game Selected: $global:selectedGame" -Color Red -NoNewline
			}
		}
		Default	{ Write-HostCenter "Game Selected: $global:selectedGame" -Color DarkCyan -NoNewline }
	}
	Write-Host "`r" -NoNewline
	if ($global:selectedGame.Length -le 7) { $extraBuffer += 1 }
	Write-HostCenter "Game Selected:" -Color DarkCyan -Buffer ($global:selectedGame.Length + [Math]::Floor($global:selectedGame.Length / 15) + $extraBuffer)
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

	if ($global:outputLines.ContainsKey("cs")) {
		foreach ($line in $global:outputLines["cs"]) {
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

	foreach ($line in $global:outputLines["browser"]) {
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
		[int]$barLength = 40,
		[System.ConsoleColor]$Color = "White"
	)

	if ($total -eq 0) { $total = 1 } 

	$percent = [math]::Round(($current / $total) * 100)
	$filledLength = [math]::Floor(($current / $total) * $barLength)
    
	$fillChar = '|'
	$emptyChar = '-'

	$bar = ($fillChar * $filledLength).PadRight($barLength, $emptyChar[0])
	$line = "$prefix [$bar] $percent%"

	Clear-CurrentLine
	Write-HostCenter "$line" -Color $Color -NoNewline
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
		"loader", "dma", "client", "cheat", "launcher", "ring1", "klar", "lethal", "cheatarmy"
	)
	$alwaysFlag = @{}
	foreach ($entry in $fdict) {
		$falsePositives[$entry.ToLower()] = $true
	}
	foreach ($entry in $adict) {
		$alwaysFlag[$entry.ToLower()] = $true
	}
	switch ($global:selectedGame) {
		"Rainbow Six Siege" {
			foreach ($entry in @("bun", "demoncore", "crusader", "tomware", "hydro", "goldcore", "mojojojo")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Counter Strike" {
			foreach ($entry in @("predator", "plague")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Call of Duty: Black Ops 6" {
			foreach ($entry in @("octave", "meta", "zen")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Fortnite" {
			foreach ($entry in @("blurred", "hyper", "dope")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"FiveM" {
			foreach ($entry in @("hx")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Escape from Tarkov" {
			foreach ($entry in @("eft")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Marvel Rivals" {
			foreach ($entry in @("infinity", "predator")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Valorant" {
			foreach ($entry in @("sky")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
		"Apex Legends" {
			foreach ($entry in @("kuno")) {
				$alwaysFlag[$entry.ToLower()] = $true
			}
		}
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
	Clear-CurrentLine
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
	return ($read.VirtualKeyCode)
}

function Install-SQLite3 {
	$global:sqlite3dir = "$env:TEMP\sqlite_temp"
	$null = Join-Path $global:sqlite3dir "sqlite3.exe"
	New-Item -ItemType Directory -Force -Path $global:sqlite3dir | Out-Null

	$sqliteUrl = "https://www.sqlite.org/2025/sqlite-tools-win-x64-3490100.zip"
	$zipPath = Join-Path $global:sqlite3dir "sqlite.zip"

	$req = [System.Net.HttpWebRequest]::Create($sqliteUrl)
	$res = $req.GetResponse()
	$stream = $res.GetResponseStream()
	$totalBytes = $res.ContentLength
	$buffer = New-Object byte[] 8192
	$bytesRead = 0

	$fileStream = [System.IO.File]::Create($zipPath)

	if (-not $fileStream) {
		Write-HostCenter "Failed to create file stream for $zipPath" -Color DarkRed -Background Red
	}

	do {
		$read = $stream.Read($buffer, 0, $buffer.Length)
		if ($read -gt 0) {
			$fileStream.Write($buffer, 0, $read)
			$bytesRead += $read
			Show-CustomProgress -current $bytesRead -total $totalBytes -prefix "Downloading SQLite3..."
		}
	} while ($read -gt 0)

	$fileStream.Close()
	$stream.Close()
	$res.Close()

	Add-Type -AssemblyName System.IO.Compression.FileSystem
	[System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $global:sqlite3dir)

	$sqliteExePath = Get-ChildItem -Recurse -Path $global:sqlite3dir -Filter "sqlite3.exe" | Select-Object -First 1
	Clear-CurrentLine
	if (-not $sqliteExePath) {
		Write-HostCenter "Failed to install SQLite3... Skipping Browser Downloads" -Color Red -NoNewline
		exit 1
	}
	$global:sqlite3 = $sqliteExePath.FullName
	Remove-Item -Path $zipPath -Force
}

function Invoke-SQLite3Cleanup {
	Remove-Item -Path $global:sqlite3dir -Recurse -Force
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

# === FUNCTION: Fetch Browser Download History
function Get-BrowserDownloadHistory {
	if (-not $global:sqlite3) { Install-SQLite3 }
	if (-not $global:sqlite3) {
		Write-HostCenter ">> Failed to Index Browser Download History <<`n`n" -Color Red -NoNewline
		return $null
	}

	$browserPaths = @{
		"Chrome"  = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
		"Edge"    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
		"Brave"   = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\History"
		"Opera"   = "$env:APPDATA\Opera Software\Opera Stable\History"
		"Firefox" = "$env:APPDATA\Mozilla\Firefox\Profiles"
	}

	$global:outputLines["browser"] = @("`n======== BROWSER DOWNLOADS ========")

	foreach ($browser in $browserPaths.Keys) {
		$path = $browserPaths[$browser]

		if ($browser -eq "Firefox") {
			if (Test-Path $path) {
				Write-HostCenter "> Firefox Browser Support Coming Soon <" -Color Yellow
			}
		}
		else {
			if (Test-Path $path) {
				Write-HostCenter "Found $browser, indexing..." -Color Green -NoNewline
				$tempCopy = Join-Path $global:sqlite3dir "$browser-Downloads.db"
				Copy-Item $path $tempCopy -Force

				$query = "SELECT target_path, datetime(start_time/1000000 - 11644473600, 'unixepoch') AS download_date, referrer FROM downloads"

				$cmd = "$global:sqlite3 `"$tempCopy`" `"$query`""
				$output = Invoke-Expression $cmd

				$progress = 0
				Clear-CurrentLine

				foreach ($line in $output) {
					Show-CustomProgress -current $progress -total ($output.Count) -prefix "Indexing $browser..." -Color Green
					$progress += 1
					if ($line -match "(.+)\|(.+)\|(.+)") {
						$result = [PSCustomObject]@{
							Browser      = $browser
							FilePath     = $matches[1].Trim()
							DownloadDate = $matches[2].Trim()
							URL          = $matches[3].Trim()
						}
						$global:outputLines["browser"] += "$($result.FilePath), $($result.URL), $($result.DownloadDate)"
						$global:foundFiles += $result.FilePath
					}
				}
				Clear-CurrentLine
				Write-HostCenter "> Indexed $browser <`n" -Color Green -NoNewline

				Remove-Item $tempCopy -Force
			}
		}
	}
	Clear-CurrentLine
	Write-Host
	Write-HostCenter ">> Indexed Browser Download History <<`n`n" -Color Green -NoNewline
	Invoke-SQLite3Cleanup
}

# === FUNCTION: Rainbow Six Siege
function Get-RainbowSixData {
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
	if ($uids.Length -eq 0) {
		$global:outputLines["r6"] += "No Rainbow Six Accounts Found!"
	}
	Write-Host
	Write-HostCenter ">> Rainbow Six Siege Accounts Revealed! <<`n" -Color DarkGreen
	Start-Sleep -Milliseconds 800
}

# === FUNCTION: Counter Strike
function Get-CounterStrikeData {
	Write-Host
	Write-HostCenter "Revealing all Counter Strike Accounts..." -Color Green
	$global:outputLines["cs"] = @("`n======== Counter Strike Accounts ========")
	$commonSteamPath = "C:\Program Files (x86)\Steam\userdata"
	$userdataPath = $null
	if (-not (Test-Path $commonSteamPath)) {
		Write-HostCenter "Steam userdata out of place, scanning system for Steam userdata..." -Color Green
		$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }
    
		foreach ($drive in $drives) {
			Write-Host "Scanning drive `"$($drive.Name):\`" for Steam userdata folder..."
			try {
				$searchMatches = Get-ChildItem -Path "$($drive.Name):\" -Directory -Recurse -ErrorAction SilentlyContinue |
				Where-Object { $_.Name -eq "userdata" -and $_.Parent.Name -eq "Steam" }

				foreach ($match in $searchMatches) {
					Write-HostCenter "Found userdata folder: $($match.FullName)" -Color Green
					$userdataPath = $match.FullName
					break
				}
			}
			catch { $null }
			if ($userdataPath) { break }
		}

		if (-not $userdataPath) {
			Write-HostCenter "Steam userdata not found on any drive." -Color Red
			Write-HostCenter "Skipping Counter Strike Scan..." -Color Green
			return
		}
	}
	else { $userdataPath = $commonSteamPath }

	$found = 0

	Write-Host
	Get-ChildItem -Path $userdataPath | ForEach-Object {
		if (Test-Path "$userdataPath\$($_.Name)\730") {
			$found++
			Write-HostCenter "Found $($_.Name)" -Color Green
			$global:outputLines["cs"] += "$($_.Name)"
			Start-Process "https://tracker.gg/cs2/profile/steam/$($_.Name)"
		}
	}
	if ($found -eq 0) {
		$global:outputLines["cs"] += "No CS2 accounts found!"
	}
	Write-Host
	Write-HostCenter ">> Counter Strike Accounts Revealed! <<`n" -Color DarkGreen
	Start-Sleep -Milliseconds 800
}

# === FUNCTION: Apex Legends
function Get-ApexLegendsData {

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
	
	Start-Sleep -Milliseconds 800
	Clear-Host

	Write-Host
	Write-HostCenter "Fetching Browser Download History..." -Color Green -Bold
	Write-HostCenter "Note: This Could Take A While...`n" -Color DarkGray
	Get-BrowserDownloadHistory
	
	Start-Sleep -Milliseconds 800
	Clear-Host

	Clear-Host
	Write-Host
	Write-HostCenter "Scanning Found Files for Suspicious Activity" -Color Magenta
	Write-HostCenter "Note: This Could Take A While...`n" -Color DarkGray
	Get-SuspiciousFiles

	Start-Sleep -Milliseconds 800
}

function Start-BasicScan {
	Start-BaseScan
	Invoke-EndScan
}

function Start-GameScan {
	Start-BaseScan
	switch ($global:selectedGame) {
		"Rainbow Six Siege" {
			Get-RainbowSixData
		}
		"Counter Strike" {
			Get-CounterStrikeData
		}
		"Apex Legends" {
			Get-ApexLegendsData
		}
	}
	Invoke-EndScan
}

#endregion

#region Run
do {
	Clear-Host
	Show-MainMenu
} while ($true)
#endregion