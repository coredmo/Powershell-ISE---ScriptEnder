# A convenient bundle of scripted utilities - Created and managed by Connor :)

#$unitList = @("webb222","thisonetoo","webb224","webb225")
$ipv4RegEx = '\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b'
$macRegEx = '\b([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})\b'
$bam = "a"
$count = 1

$choosing = $true
$validCmd = @('ping','p')

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$parts = $currentUser -split '\\'
$username = $parts[-1] # Gets the current users name and strips its domain name

$orig_fg_color = $host.UI.RawUI.ForegroundColor

# Ignores error handling
function C { $global:correct = $true }

    # THE HELP MENU
function Help {
Write-Host @"

The Help Menu:

help | h: List this menu

terminal |  term |  t: Start-Process cmd.exe or powershell.exe
search   |  ad   |  s: Search your PC's active directory computer descriptions and query for MAC addresses
wake     |  wol  |  w: Send a magic packet to a MAC Address, UDP via port 7
ping     |          p: Ping a selected host in 3 different modes
exprs    |         rs: Restart and open Windows Explorer
gpupdate |  gpu  | gp: Run a simple forced group policy update
              booyeah: -

Often times Y = "e" and N = "q"

- Connor's Scripted Toolkit (ISE Iteration 1)-
https://github.com/coredmo/Powershell-ISE---ScriptEnder`n
"@
Write-Host "Press enter to return..."
$noid = Read-Host -Debug; Clear-Host
if ($noid -ieq "dingus") { Start-Process "https://cat-bounce.com/" } elseif ($noid -ieq " ") { Write-Host "dingus" }
}

    # Recents and AD functionality
        #region

    # Search the local active directory's computer descriptions (I never learned to comment ig)
function Scan-Create {
    $adMode = $true
    $preBreak = $false
    $pingConfig = $false
    $adLoop = $true
    while ($adLoop) {

        Write-Host "Do you want to enable host pinging? Y | Yes - N | No"
        $adInput = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
        switch ($adInput) {
            {$_ -in "y", "e"} {
                $dcIP = (Resolve-DnsName -Name (Get-ADDomainController).HostName | Select-Object -ExpandProperty IPAddress).ToString()
                $pingConfig = $true; $adLoop = $false; [System.Console]::Clear(); "Pinging each selected host"
            } {$_ -in "n", "q"} { $pingConfig = $false; $adLoop = $false; [System.Console]::Clear(); "Skipping ping function" }
        }
        Clear-Host
    }
    while ($adMode -eq $true) {

        if ($savedConfo -eq $true -and $recents.Count -gt 0) { 
            $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "Recent Results:`n $recents"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
        do {
            Write-Host "- Enter any piece of a pc's active directory description or leave it blank to return to the console -"
            $input = Read-Host "You can press 'c' while its querying to abort the process`n>"
            if (-not $input) {
                [System.Console]::Clear();
                $adMode = $false
                $preBreak = $true; break
            }
        } while (-not $input)
        [System.Console]::Clear();
        if ($preBreak -eq $true) { continue }
    
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "Showing results for $input`n"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    
        $result = Get-ADComputer -Filter "Description -like '*$input*'" -Properties Description
        $dcTarget = $false
    
        $global:unitList = @();
        if ($result) {
            foreach ($computer in $result) {
                $cancelResult = $false
                if ([System.Console]::KeyAvailable -and [System.Console]::ReadKey().Key -eq "C") {
                    Write-Host " button pressed:`nAborting query..."
                    Start-Sleep -Milliseconds 60
                    $cancelResult = $true
                }
                if ($cancelResult) { break }
                $global:unitlist += $computer.Name
    
                Write-Host "$($computer.Name), $($computer.Description)"
                $nsResult = nslookup $($computer.Name)
                $nsRegex = "(?:\d{1,3}\.){3}\d{1,3}(?!.*(?:\d{1,3}\.){3}\d{1,3})"
                $nsMatches = [regex]::Matches($nsResult, $nsRegex)
                if ($pingConfig -eq $true) { 
                    if ($dcIP -notcontains $nsMatches) {
                        $pingResult = ping -n 1 $nsMatches
                        if (-not $?) { $host.UI.RawUI.ForegroundColor = "Red"; "$pingResult"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                        else { $host.UI.RawUI.ForegroundColor = "Green"; "The host '$nsMatches' was pinged successfully"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                    } else { 
                        $host.UI.RawUI.ForegroundColor = "Red"
                        "Ping skipped: Target is the domain controller"
                        $host.UI.RawUI.ForegroundColor = $orig_fg_color
                        $dcTarget = $true
                    }
                }
                $macResult = arp -a | findstr "$nsMatches"
                if ($macResult -eq $null -or $macResult -eq '') {
                    if ($pingResult -like "*Request timed out.*" -or $pingResult -like "*could not find host*") { $diffLan = $false } else { $diffLan = $true }
                    if ($diffLan -eq $true) {
                    $host.UI.RawUI.ForegroundColor = "Yellow"
                    if ($dcTarget -eq $false) { Write-Host "  This host may be in a different LAN" }
                    $dcTarget = $false
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                    $diffLan = $false
                    }
                }
                $host.UI.RawUI.ForegroundColor = "Yellow"; Write-Host "$macResult`n"; $host.UI.RawUI.ForegroundColor = $orig_fg_color
                "----------------------------"
            }
        } else {
            Write-Host "No results found for $input`n"
        }
        Write-Host "`nPress any key to reset or press S to save this list to the recents list`nPress c to return to the command line..."
        $adOption = [System.Console]::ReadKey().Key; [System.Console]::Clear();
        if ($adOption -ieq "c") { $adMode = $false }
        elseif ($adOption -ieq "s") { $recents = $unitList; $savedConfo = $true }
    }
}

function Invoke-Recents {
    # "`n------------`n"
    foreach ($compObj in $unitList) {
        $noArp = $false
        $cancelResult = $false
        if ([System.Console]::KeyAvailable -and [System.Console]::ReadKey().Key -eq "C") {
            Write-Host " button pressed:`nAborting query..."
            Start-Sleep -Milliseconds 60
            $cancelResult = $true
        }
        if ($cancelResult) { break; Invoke-Recents }

        Write-Host "$count - $compObj`n"
        $count++

        # Too Slow
        #$pingResult = ping -n 1 $compObj
        #if ($pingResult -match $pingRegEx) {
        #    $pingResultV4 = [regex]::Matches($pingResult, $ipv4RegEx) | ForEach-Object { $_.Value }
        #    $resultV4[0]
        #}
        
        $ipv4Result = nslookup $compObj
        $nsResultV4 = [regex]::Matches($ipv4Result, $ipv4RegEx) | ForEach-Object { $_.Value }
        if ($nsResultV4.Count -lt 2) {
            Write-Host "`nSkipping $compObj due to nslookup failure.`n`n------------`n"
            continue
        } else { $resultV4 = $nsResultV4[1] }

        $arpResult = arp -a | findstr "$resultV4"
        if (-not $arpResult -and -not [regex]::Matches($arpResult, $macRegEx)) {
            Write-Host "No ARP entry found for $resultV4.`n"
            $noArp = $true
        } else { $mac = [regex]::Matches($arpResult, $macRegEx) }
        
        if ($noArp -eq $false) { "MAC Address:`n$mac`n" }
        "IPv4: "; $resultV4
        "`n------------`n"
    }
    $count = 1
    Read-Host
}
        #endregion

    #Utilities
        #region

    # Start-Process cmd.exe or powershell.exe
function Terminal {
    $folderPath = "C:\users\$username"
    Write-Host "Do you want to start the instance in Administrator? Y or E - Yes"
    $tchoose1 = [System.Console]::ReadKey().Key
    [System.Console]::Clear()
    
    Write-Host "Press E for cmd.exe or press Q for powershell.exe"
    $tchoose2 = [System.Console]::ReadKey().Key
    [System.Console]::Clear()
    
    if ($tchoose2 -ieq "e") {
        if ($choose -ieq "y" -or $tchoose1 -ieq "e") { Start-Process cmd.exe -Verb RunAs -WorkingDirectory $folderPath }
        else { Start-Process cmd.exe -WorkingDirectory $folderPath }
    } 
    elseif ($tchoose2 -ieq "q") {
        if ($choose -ieq "y" -or $tchoose1 -ieq "e") { Start-Process powershell.exe -Verb RunAs -WorkingDirectory $folderPath }
        else { Start-Process powershell.exe -WorkingDirectory $folderPath }
    } 
    else { $host.UI.RawUI.ForegroundColor = "Red"
        Write-Host "Invalid"; $host.UI.RawUI.ForegroundColor = $orig_fg_color
    }
    exit
}

    # Send a magic packet to a MAC Address, UDP via port 7
function Invoke-WOL {
    $wolMode = $true
    while ($wolMode -eq $true) {
        if ($recentMode -eq $true) { $mac = $recentMAC }
        else { $mac = Read-Host "Input a MAC Address or leave it blank to return" }
        if ($mac -eq $null -or $mac -eq '') { $wolMode = $false; Clear-Host }
        else {
            $macByteArray = $mac -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
            [Byte[]] $magicPacket = (,0xFF * 6) + ($macByteArray  * 16)
            $udpClient = New-Object System.Net.Sockets.UdpClient
            $udpClient.Connect(([System.Net.IPAddress]::Broadcast),7)
            $udpClient.Send($MagicPacket,$MagicPacket.Length)
            $udpClient.Close()
            Write-Host "$mac --- $macByteArray"
            Start-Sleep -Milliseconds 2800
            if ($recentMode -eq $true) { $wolMode = $false; Clear-Host }
        }
    }
}

    # Run a simple group policy update
function Group-Policy {
    Write-Host "Running Group Policy Update"
    gpupdate
    Write-Host "Press any key to continue..."
    [System.Console]::ReadKey().Key
}

    # Ping a selected host in different modes
function Ping-Interface {
    $pingOption = $true
    while ($pingOption -eq $true) {
        if ($prePing -eq $null) { 
            do {
                $pingIP = Read-Host "- Easy ping utility - Enter an IP -`n>"
                if (-not $pingIP) {
                    [System.Console]::Clear();
                    $host.UI.RawUI.ForegroundColor = "Red"
                    Write-Host "Error: Input cannot be blank. Please enter a valid string."
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                }
            } while (-not $pingIP) 
        }
    
        do {
            $eValues = @('a', 'b', 'c')
            Write-Host "Pinging '$pingIP'`n`nWhat type of scan do you want?`nA - 5 attempts | B - 1 attempts | C - Indefinite"
            $n = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
            if ($eValues -notcontains $n) {
                [System.Console]::Clear();
                $host.UI.RawUI.ForegroundColor = "Red"
                Write-Host "Error: Input cannot be blank or incorrect. Please enter a valid option."
                $host.UI.RawUI.ForegroundColor = $orig_fg_color
            }
        } while ($eValues -notcontains $n)
        [System.Console]::Clear()
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "Processing Ping..."
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    
        if ($n -ieq "a") { $n = 5 } elseif ($n -ieq "b") { $n = 1 }
        if ($n -ieq "c") { $constPing = $true } else { $pingResult = ping -n $n $pingIP }
    
        if ($constPing -eq $true) { Write-Host "Press C at any point to cancel" }
        while ($constPing -eq $true) {
            $pingResult = ping -n 1 $pingIP
            "$pingResult`n"
            Start-Sleep -Milliseconds 500
            if ([System.Console]::KeyAvailable -and [System.Console]::ReadKey().Key -eq "C") {
                Write-Host " > Abort button pressed:`nPress any key to continue"
                [System.Console]::ReadKey().Key
                $constPing = $false
            }
        }
    
        [System.Console]::Clear()
        $pingResult
    
        $host.UI.RawUI.ForegroundColor = "Yellow"
        Write-Host "`nPress any key to restart or press C to return to the console"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    
        $cancel = [System.Console]::ReadKey().Key
        [System.Console]::Clear()
        if ($cancel -ieq "c") { $pingOption = $null }
    }
    [System.Console]::Clear()
    $prePing = $null
}
        #endregion

while ($choosing) {
    $correct = $false

    # Read a command from a user and split it if they add extra parameters
    Write-Host "`nType a command or 'help' for a list of commands"
    $choice = Read-Host ">"; $choice = $choice.Trim()
    [System.Console]::Clear()
    if ($choice -ieq "a command") { C; ":D" }
    
    $tokens = $choice -split '\s+', 2
    $choice = $tokens[0]

    switch ($choice) { 

        {$_ -in "help", "h"} { C; Help }
        
        {$_ -in "ad", "search", "s"} { C; Scan-Create }

        {$_ -in "recents", "recent", "rec", "r"} { C; Invoke-Recents }

        {$_ -in "ping","p"} { C; Ping-Interface }

        {$_ -in "wake","wol","w"} { C; Invoke-WOL }

        {$_ -in "gpupdate","gp"} { C; Group-Policy }

        {$_ -in "terminal","term","t"} { C; Terminal }

        {$_ -in "exprs","rs"} { C; Stop-Process -Name explorer -Force; Start-Process explorer } # Restart and open Windows Explorer
    }

    if ($correct -eq $true) {
        continue
    } else {
        Clear-Host
        $host.UI.RawUI.ForegroundColor = "Red"
        Write-Host "Please input an actual command or follow the latter half of these here instructions"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
    }
}