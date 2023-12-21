#The script to end scripting - Created by Connor :)

$validCmd = @('new','n','open','o','edit','e','debug') # Commands that can use a directory
$option = "none"

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$parts = $currentUser -split '\\'
$username = $parts[-1] # Gets the current users name and strips its domain name

$orig_fg_color = $host.UI.RawUI.ForegroundColor

$selected = $false
$name = $null
$dir = $null
$dirInput = $null
$proEdit = $true

while ($option -eq "none") {
    $correct = $false
    $preDir = $false
    $preName = $false
    $isMade = $true
    $noArg = $false
    $dirInit = $false
    
    if ($selected -eq $true) {
        $dir = Split-Path -Path $dirInput -Parent
        $name = Split-Path -Path $dirInput -Leaf
        if ($dir.EndsWith("\")) { $dir = $dir.Substring(0, $dir.Length - 1) }
        Write-Host "`nSelected file: $name`nDirectory: $dir"
    } # When $selected is set to true, it removes any extra backslashes from $dir and displays both the ($dir = directory :) and ($name = the file name)

    Write-Host "`nType a command or 'help' for a list of commands"
    $choice = Read-Host ">"; $choice = $choice.Trim()

    if ($choice -ieq "a command" -or $choice -ieq "clr") { $correct = $true; ":D"; Start-Sleep -Milliseconds 1 }

    $tokens = $choice -split '\s+', 2
    $choice = $tokens[0]
    # ^ This will split something like "open C:\this thing.ps1" into "open" and "C:\this thing.ps1"
    # v This will check if the input is a valid command and if so, make sure the extra part is a valid path to a script/directory.
    if ($validCmd -contains $choice) {
        if ($tokens.Count -eq 2) {
            $dirPart = $tokens[1]
            if ($dirPart.EndsWith("\")) { $dirPart = $dirPart.Substring(0, $dirPart.Length - 1) }
            if ([System.IO.Path]::IsPathRooted($dirPart)) {
                $fileExtension = try { (Get-Item $dirPart -ErrorAction SilentlyContinue).Extension }
                    catch { [System.IO.Path]::GetExtension($dirPart); "Alt Mode"; Start-Sleep -Seconds 1 }
                switch ($choice) {
                    "open" {
                        if ((Test-Path $dirPart -PathType Leaf) -and $fileExtension -eq '.ps1') {
                            $dirInit = $true
                        } else {
                            $noArg = $true
                            $choice = $null
                        }
                    }
                    "new" {
                        if ($fileExtension -eq '.ps1') {
                            $dirInit = $true
                            $preName = $true
                        } else { $dirInit = $true }
                    }
                }
            } else {""}
        }
    }
    Clear-Host
    
    if ($noArg) { 
    $host.UI.RawUI.ForegroundColor = "Red"
    Write-Host @"

Invalid argument. You must provide a .ps1 file
Example: open c:\users\$username\test file\new.ps1." 

You may input a directory or new file name with the new command:
Example: new c:\users\$username\new folder
NewFile: new c:\users\$username\new folder\new.ps1
"@
    $host.UI.RawUI.ForegroundColor = $orig_fg_color 
    $correct = $true
    $noArg = $false
    }

    switch ($choice) {
        # THE HELP MENU - Uses $correct to skip the "Input an actual command" error
        {$_ -in "help", "h"} {
            Write-Host @"

The Help Menu:

help: List this menu
new: Create a new Powershell script file
open: Select an existing .ps1 file as active
edit: It's prophesized to at least contain something
search | ad | s: Search your PC's active directory computer descriptions and query for MAC addresses
wake   | wol: Send a magic packet to a MAC Address, UDP via port 7
exprs  |  rs: Restart and open Windows Explorer
booyeah:

You can add a file path after a command or create a new script in the current directory
Example: open C:\users\$username\my creation.ps1
Example: new here   |   nh

Often times Y = "e" and N = "q"

(Debug) fit: fill dir
        e: check dir

- Connor's Scripted ISE & Toolkit -
https://github.com/coredmo/Powershell-ISE---ScriptEnder`n
"@
            Write-Host "Press any key to return..."
            $noid = Read-Host -Debug
            if ($noid -ieq "dingus") { Start-Process "https://cat-bounce.com/" }
            Clear-Host
            if ($noid -ieq " ") { Write-Host "You can use the first letter of the commands to execute them as well" }
            $correct = $true
        }

        # Create a new .ps1 script file in any directory with any name. (Requires admin to create files in some locations)
        {$_ -in "new", "n"} {
            while ($dirInit -eq $true) {
                Write-Host "Do you want to make $dirPart`nand set it as the designated file/folder?`nY = Yes | N = No"
                $choose = [System.Console]::ReadKey().Key; [System.Console]::Clear()
                switch ($choose) {
                    {$_ -in "y","e"} { 
                        $preDir = $true
                        $dirInit = $false
                        $newInput = $dirPart
                        $dir = $newInput
                    }
                    {$_ -in "n","q"} {
                        $dirInit = $false
                    }
                }
            }

            if ($preDir -eq $false) {
            Write-Host "`nWhat directory will the file be created in? Example: C:\users\$username`nYour C:\ starting folder may not allow you to create a new file."
            $newInput = Read-Host ">"; $newInput = $newInput.Trim()
            if ($newInput.EndsWith("\")) { $newInput = $newInput.Substring(0, $newInput.Length - 1) }
            $dir = $newInput
            Clear-Host 
            } # MAKE THIS HAVE A BETTER ERROR MESSAGE, IT USES THE DEFAULT ONE


            if (![string]::IsNullOrEmpty($newInput)) {
                if ([System.IO.Path]::IsPathRooted($newInput)) {
                    if ($preName -eq $false) {
                        Write-Host "`nDirectory is compatible`nWhat is the name of your new script?"
                        $name = Read-Host ">"; $name.Trim()
                    } else { $preLeaf = $true }

                    if ($preLeaf -eq $false) { $name = $name.Replace(".ps1","") }
                    try {
                        Write-Host "`n$dir\$name.ps1"
                        try {
                            New-Item -Path "$dir" -ItemType Directory -ErrorAction SilentlyContinue
                            if ($preLeaf) { New-Item -Path "$dir\$name" -ItemType File -ErrorAction Continue }
                            else { New-Item -Path "$dir\$name.ps1" -ItemType File -ErrorAction Continue }
                        } catch {
                            $successful = $false
                        }
                        if ($successful) { Write-Host "File successfully created."; $dirInput = "$dir\$name.ps1"; $selected = $true }
                        $correct = $true
                        break
                    } catch {
                        $host.UI.RawUI.ForegroundColor = "Red"
                        Write-Host "Error creating the file: $_"
                        $host.UI.RawUI.ForegroundColor = $orig_fg_color
                        $correct = $true
                    }
                } else {
                    $host.UI.RawUI.ForegroundColor = "Red"
                    Write-Host "The specified path is not a valid directory."
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                    $correct = $true
                }
            } else {
                $host.UI.RawUI.ForegroundColor = "Red"
                Write-Host "Please enter a valid directory."
                $host.UI.RawUI.ForegroundColor = $orig_fg_color
                $correct = $true
            }
        }  

        # Direct the script to any available .ps1 scripts and it will assign itself to it
        {$_ -in "open", "o"} {
            while ($dirInit -eq $true) {
                Write-Host "Do you want to select $dirPart`nand set it as the designated file?`nY = Yes | N = No"
                $choose = [System.Console]::ReadKey().Key
                switch ($choose) {
                    {$_ -in "y","e"} { 
                        $preDir = $true
                        $dirInit = $false
                        $openInput = $dirPart
                    }
                    {$_ -in "n","q"} {
                        $dirInit = $false
                    }
                }
            }

            if ($preDir -eq $false) {
            Write-Host "`nPlease enter the directory of the powershell script you want to edit`nExample: C:\Users\$username\Desktop\whatImMaking.ps1`nIt must have a .ps1 extension"
            $openInput = Read-Host ">"; $openInput = $openInput.Trim(); if ($openInput.EndsWith("\")) { $openInput = $openInput.Substring(0, $openInput.Length - 1) }
            try { $fileExtension = (Get-Item $dirPart).Extension } catch {""} }

            if (![string]::IsNullOrEmpty($openInput)) {
                if ($fileExtension -ieq ".ps1" -and (Test-Path $openInput -PathType Leaf)) {
                    $dir = Split-Path -Path $openInput -Parent
                    $name = Split-Path -Path $openInput -Leaf
                    Clear-Host
                    $selected = $true
                    $correct = $true
                } else {
                    Clear-Host
                    $host.UI.RawUI.ForegroundColor = "Red"
                    Write-Host "Please enter an actual directory`nRemember to add the .ps1 extension"
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                }
            } else {
                Clear-Host
                $host.UI.RawUI.ForegroundColor = "Red"
                Write-Host "Please enter a valid path to a powershell_script.ps1 `nExample: C:\users\$username\script.ps1"
                $host.UI.RawUI.ForegroundColor = $orig_fg_color
            }
            $correct = $true
        }

        # Add descriptive information, create variables, and pre-made/custom script pieces using the inputted variables
        {$_ -in "edit", "e"} {
            if ($dirInput -ne $null) { 
                if (Test-Path $dirInput -PathType Leaf) {
                    $content = Get-Content $dirInput
                    $cursorPosition = 0
                while ($proEdit -eq "true") {
                    Clear-Host
                    $content | ForEach-Object { Write-Host $_ }

                    $host.UI.RawUI.ForegroundColor = "Yellow"
                    Write-Host @"


     |---------------------|
Write-Host "Arrow keys: Navigate"
Write-Host "Backspace: Delete"
Write-Host "Enter: Save and exit"
Write-Host "Q: Quit without saving"
"@
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color

                    $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
                    if ($key -eq "`0") {
                        $key = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").VirtualKeyCode
                        switch ($key) {
                            37 { $cursorPosition = [Math]::Max(0, $cursorPosition - 1) }
                            39 { $cursorPosition = [Math]::Min($content.Count, $cursorPosition + 1) }
                            8  { 
                                if ($cursorPosition -gt 0) {
                                    $content = $content[0..($cursorPosition - 2)] + $content[$cursorPosition..($content.Count - 1)]
                                    $cursorPosition--
                                }
                            }
                        }
                    }
                    elseif ($key -eq "`r") {
                         # Replace/edit logic
                    }
                    elseif ($key -eq "`enter") {
                        try { Set-Content -Path $filePath -Value $content } catch { Write-Host "Error saving..."; Start-Sleep -Seconds 2 }
                        Write-Host "Saved and exited."
                        $proEdit = $false
                        break
                    }
                    elseif ($key -eq "q") {
                        Write-Host "Exited without saving."
                        $proEdit = $false
                        break
                    }
                    else {
                        $content = $content[0..($cursorPosition - 1)] + $key + $content[$cursorPosition..($content.Count - 1)]
                        $cursorPosition++
                    }
                }
            } 
                else {
                Write-Host "The specified file does not exist.`nExiting the script..."
                $correct = $true
                Start-Sleep -Seconds 2
                Clear-Host
            } } else {
                Write-Host "No files are selected`nExiting..."
                Start-Sleep -Seconds 2
                $correct = $true
                Clear-Host
            }
        }

        # Search the local active directory's computer descriptions
        {$_ -in "ad", "search", "s"} {
            $adMode = $true
            $pingConfig = $false
            $adLoop = $true
            while ($adLoop) {
                Write-Host "Do you want to enable host pinging? Y | Yes - N | No"
                $adInput = $Host.UI.RawUI.ReadKey("IncludeKeyDown,NoEcho").Character
                if ($adInput -ieq "y" -or $adInput -ieq "e") { $pingConfig = $true; $adLoop = $false; "Pinging each selected host" }
                if ($adInput -ieq "n" -or $adInput -ieq "q") { $pingConfig = $false; $adLoop = $false; "Skipping ping function"}
            }
            while ($adMode -eq $true) {
                do {
                    $input = Read-Host "Enter the first or last name of the associate you want to search for"
                    if (-not $input) {
                        [System.Console]::Clear();
                        $host.UI.RawUI.ForegroundColor = "Red"
                        Write-Host "Error: Input cannot be blank. Please enter a valid name."
                        $host.UI.RawUI.ForegroundColor = $orig_fg_color
                    }
                } while (-not $input)

                $host.UI.RawUI.ForegroundColor = "Yellow"
                Write-Host "Showing results for $input`n"
                $host.UI.RawUI.ForegroundColor = $orig_fg_color

                $result = Get-ADComputer -Filter "Description -like '*$input*'" -Properties Description

                if ($result) {
                    foreach ($computer in $result) {
                        Write-Host "$($computer.Name), $($computer.Description)"
                        $nsResult = nslookup $($computer.Name)
                        $nsRegex = "(?:\d{1,3}\.){3}\d{1,3}(?!.*(?:\d{1,3}\.){3}\d{1,3})"
                        $nsMatches = [regex]::Matches($nsResult, $nsRegex)
                        if ($pingConfig -eq $true) { 
                            $pingResult = ping -n 1 $nsMatches
                            if (-not $?) { $host.UI.RawUI.ForegroundColor = "Red"; "$pingResult"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                            else { $host.UI.RawUI.ForegroundColor = "Green"; "The host '$nsMatches' was pinged successfully"; $host.UI.RawUI.ForegroundColor = $orig_fg_color }
                        }
                        $macResult = arp -a | findstr "$nsMatches"
                        if ($macResult -eq $null -or $macResult -eq '') {
                            if ($pingResult -like "*Request timed out.*" -or $pingResult -like "*could not find host*") { $diffLan = $false } else { $diffLan = $true }
                            if ($diffLan -eq $true) {
                            $host.UI.RawUI.ForegroundColor = "Yellow"
                            Write-Host "This host may be in a different LAN"
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
                Write-Host "`nPress any key to refresh...`nPress c to return to the command line..."
                $adOption = [System.Console]::ReadKey().Key; [System.Console]::Clear();
                if ($adOption -ieq "c") { $adMode = $false; $correct = $true}
            }
        }

        # Send a magic packet to a MAC Address, UDP via port 7
        {$_ -in "wake","wol","w"} {
            $wolMode = $true
            while ($wolMode -eq $true) {
	            $mac = Read-Host "Input a MAC Address or leave it blank to return"
                if ($mac -eq $null -or $mac -eq '') { $wolMode = $false; $correct = $true; Clear-Host } 
                else {
	                $macByteArray = $mac -split "[:-]" | ForEach-Object { [Byte] "0x$_"}
	                [Byte[]] $magicPacket = (,0xFF * 6) + ($macByteArray  * 16)
	                $udpClient = New-Object System.Net.Sockets.UdpClient
	                $udpClient.Connect(([System.Net.IPAddress]::Broadcast),7)
	                $udpClient.Send($MagicPacket,$MagicPacket.Length)
	                $udpClient.Close()
	                Start-Sleep -Seconds 3
                    Write-Host "$mac --- $macByteArray"
                }
            }
        }

        # Restart and open Windows Explorer
        {$_ -in "exprs","rs"} { Stop-Process -Name explorer -Force; Start-Process explorer; $correct = $true }

        # Check what the directory is (Debug)
        "e" { "$dirInput <Active- dirs -Potential> $dirPart"; "$fileExtension"; [System.Console]::ReadKey().Key; [System.Console]::Clear(); }

        # Set the directory to a preset (Debug)
        "fit" {
            while ($isMade) {
                Write-Host "Press a for a real file -11/29/2023-, press d for a fake one (for if the file no longer exists)`npress c to cancel"
                $fitChoice = [System.Console]::ReadKey().Key
                [System.Console]::Clear()
                switch ($fitChoice) {
                    "a" {
                        $dirInput = "C:\Users\connorr\t h\new.ps1\"
                        $selected = $true
                        $correct = $true
                        $isMade = $false }
                    "d" {
                        $dirInput = "C:\users\Connor\new.ps1\"
                        $selected = $true
                        $correct = $true
                        $isMade = $false }
                    "c" {
                        $selected = $true
                        $correct = $true
                        $isMade = $false }
                }
                if ($dirInput.EndsWith("\")) { try { $dirInput = $dirInput.Substring(0, $dirInput.Length - 1) } catch {""}}
                Clear-Host
                "The Directory is a path?"; Test-Path $dirInput -PathType Leaf
            }
        }

        # ;)
        "booyeah" {
            "Opening 300 instances of the calculator..."
            Start-Sleep -Milliseconds 1800
            "jk"; Start-Sleep -Milliseconds 650; "jk"
            Start-Sleep -Milliseconds 1000
            $correct = $true
            while ($true) { 
                Write-Host "Press A-debug or B-fibba"
                $choose = [System.Console]::ReadKey().Key
                [System.Console]::Clear()
                if ($choose -ieq "a") {
                    $option = "debug"
                    break
                } elseif ($choose -ieq "b") {
                    $option = "fibba" 
                    break
            } Clear-Host }
        }
    }

    $dirPart = $null
    if ($correct -eq $true) {
        continue
    }

    Clear-Host
    $host.UI.RawUI.ForegroundColor = "Red"
    Write-Host "Please input an actual command or follow the latter half of these here instructions"
    $host.UI.RawUI.ForegroundColor = $orig_fg_color
}

while ($option -eq "fibba") {
    Write-Host "`nDebug & test section 1"
    Write-Host "`nPress any key to start the Fibonacci Mode..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Clear-Host
    # Fib(b)onacci Mode
    $fib = 1
    $bon = 0
    while ($true) {
        "`nFibonacci Mode: Active`nPress C to cancel`n"
        $acci = $fib + $bon
        $fib = $bon
        $bon = $acci
        $host.UI.RawUI.ForegroundColor = "Green"
        "     $acci"
        $host.UI.RawUI.ForegroundColor = $orig_fg_color
        Start-Sleep -Milliseconds 500
        Clear-Host
        if ([System.Console]::KeyAvailable -and [System.Console]::ReadKey().Key -eq "C") { [System.Console]::Clear(); break }
    }
    Start-Sleep -Milliseconds 500
}

while ($option -eq "debug") {
    Write-Host "This is a debug section"
    Start-Sleep -Milliseconds 20
}