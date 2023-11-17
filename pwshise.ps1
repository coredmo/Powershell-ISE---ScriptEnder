#The script to end scripting - Created by Connor :)

while ($true) { $choose = [System.Console]::ReadKey().Key
[System.Console]::Clear()
if ($choose -ieq "a") {
    $choose = "none"
    break
} elseif ($choose -ieq "b") {
    $choose = "debug" # Could I have made this change $option? WhendidIask?
    break
}}
$option = "$choose" # This chooses which area of the script to start - "none" or "debug" - This functionality will go away

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$parts = $currentUser -split '\\'
$username = $parts[-1] # This gets the current users name and strips its domain name

$orig_fg_color = $host.UI.RawUI.ForegroundColor

$selected = $false
$name = $null
$dir = $null
$fullPath = $null
$proEdit = $true

while ($option -eq "none") {
    $correct = $false
    $preDir = $true
    
    if ($selected -eq $true) {
        $dir = Split-Path -Path $fullPath -Parent
        $name = Split-Path -Path $fullPath -Leaf
        if ($dir.EndsWith("\")) { $dir = $dir.Substring(0, $dir.Length - 1) }
        Write-Host "`nSelected file: $name`nDirectory: $dir"
    } # When $selected is set to true, it removes any extra backslashes from $dir and displays both the ($dir = directory :) and ($name = the file name)

    Write-Host "`nType a command or 'help' for a list of commands"
    $choice = Read-Host ">"; $choice = $choice.Trim()
    $regex = "^\s*([^ ]+)\s*(.*)$" # The regular expression ^\s*([^ ]+)\s*(.*)$ matches any leading whitespace
    if ($choice -match $regex) { 
        $choice = $matches[1].ToLower()
        $fullPath = $matches[2]
        $regDep = $true
    } # Splits the command and directory into two variables 
    Clear-Host

    switch ($choice) {
        # THE HELP MENU - Uses $correct to skip the "Input an actual command" error
        "help" {
            Write-Host @"

The Help Menu:

help: List this menu
new: Create a new Powershell script file
open: Select an existing .ps1 as active | You can add a path after open <path>
edit: It's prophesized to at least contain something
booyeah

"@
            Write-Host "Press any key to restart the script..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-Host
            $correct = $true
        }

        # Create a new .ps1 script file in any directory with any name. (Requires admin to create files in some locations)
        "new" {
            while ($true) {
                while ($regDep -eq $true) {
                    Write-Host "Do you want to make $fullPath`nas the designated file?`nY = Yes | N = No"
                    $choose = [System.Console]::ReadKey().Key
                    switch ($choose) {
                        "Y" { 
                            $preDir = $false
                            $regDep = $false
                        }
                        "N" {
                            $regdep = $false
                        }
                    }
                }
                Write-Host "`nWhat directory will the file be created in? Example: C:\users\$username`nYour C:\ starting folder may not allow you to create a new file."
                $dir = Read-Host ">"; $dir = $dir.Trim()
                Clear-Host
                if (![string]::IsNullOrEmpty($dir)) {
                    if (Test-Path $dir -PathType Container) {
                        Write-Host "`nDirectory exists..."
                        Set-Location -Path $dir
                        $currentdir = Get-Location
                        Write-Host "What is the name of your new script?"
                        $name = Read-Host ">"; $name.Trim()
                        try {
                            Write-Host "`n$currentdir\$name.ps1"
                            New-Item -Path "$currentdir\$name.ps1" -ItemType File -ErrorAction Stop
                            $fullPath = "$currentdir\$name.ps1"
                            Write-Host "File successfully created."
                            $selected = $true
                            $correct = $true
                            break
                        } catch {
                            $host.UI.RawUI.ForegroundColor = "Red"
                            Write-Host "Error creating the file: $_"
                            $host.UI.RawUI.ForegroundColor = $orig_fg_color
                            continue
                        }
                    } else {
                        $host.UI.RawUI.ForegroundColor = "Red"
                        Write-Host "The specified path is not a valid directory."
                        $host.UI.RawUI.ForegroundColor = $orig_fg_color
                    }
                } else {
                    $host.UI.RawUI.ForegroundColor = "Red"
                    Write-Host "Please enter a valid directory path."
                    $host.UI.RawUI.ForegroundColor = $orig_fg_color
                }
            } 
        }

        # Direct the script to any available .ps1 scripts and it will assign itself to it
        "open" {
            while ($regDep -eq $true) {
                Write-Host "Do you want to select $fullPath`nas the designated file?`nY = Yes | N = No"
                $choose = [System.Console]::ReadKey().Key
                switch ($choose) {
                    "Y" { 
                        $preDir = $false
                        $regDep = $false
                    }
                    "N" {
                        $regdep = $false
                    }
                }
            }
            if ($preDir -eq $true) {
            Write-Host "`nPlease enter the directory of the powershell script you want to edit`nExample: C:\Users\$username\Desktop\whatImMaking.ps1`nIt must have a .ps1 extension"
            $fullPath = Read-Host ">"; $fullPath = $fullPath.Trim(); if ($fullPath.EndsWith("\")) { $fullPath = $fullPath.Substring(0, $fullPath.Length - 1) }
            }
            if (![string]::IsNullOrEmpty($fullPath)) {
                if (Test-Path $fullPath -PathType Leaf) {
                    $dir = Split-Path -Path $fullPath -Parent
                    $name = Split-Path -Path $fullPath -Leaf
                    Clear-Host
                    $selected = $true
                    $correct = $true
                } else {
                    Clear-Host
                    $host.UI.RawUI.ForegroundColor = "Red"
                    Write-Host "Please enter an actual directory`nRemember to add the name of the powershell script you want to edit with the .ps1 extension"
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
        "edit" {
            if ($fullPath -ne $null) { 
                if (Test-Path $fullPath -PathType Leaf) {
                    $content = Get-Content $fullPath
                    $cursorPosition = 0

                while ($proEdit -eq $true) {
                    Clear-Host
                    $content | ForEach-Object { Write-Host $_ }

                    Write-Host @"
      ---------------------
Write-Host "Arrow keys: Navigate"
Write-Host "Backspace: Delete"
Write-Host "Enter: Save and exit"
Write-Host "Q: Quit without saving"
"@

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
                         # Replace logic
                         # You can add logic to replace text
                    }
                    elseif ($key -eq "`enter") {
                        Set-Content -Path $filePath -Value $content
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
                Start-Sleep -Seconds 2
                Clear-Host
            } } else {
                Write-Host "No files are selected`nExiting..."
                Start-Sleep -Seconds 2
                Clear-Host
            }
        }

        "fit" {
            $fullPath = "C:\users\connorr\new.ps1"
            $selected = $true
            $correct = $true
        }

        # ;)
        "booyeah" {
            "Opening 300 instances of the calculator..."
            Start-Sleep -Seconds 2
            "jk"; Start-Sleep -Milliseconds 750; "jk"
            Start-Sleep -Seconds 2
            $correct = $true
            while ($true) { 
                Write-Host "Press A or B"
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

    if ($correct -eq $true) {
        continue
    }

    Clear-Host
    $host.UI.RawUI.ForegroundColor = "Red"
    Write-Host "Please input an actual command or follow the latter half of these here instructions"
    $host.UI.RawUI.ForegroundColor = $orig_fg_color
}

while ($option -eq "fibba") {
    Write-Host "`nDebug & test section"
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
    if ($fullPath -ne $null) { 
    if (Test-Path $fullPath -PathType Leaf) {
    $content = Get-Content $fullPath
    $cursorPosition = 0

    while ($true) {
        Clear-Host
        $content | ForEach-Object { Write-Host $_ }

        Write-Host @"
      ---------------------
Write-Host "Arrow keys: Navigate"
Write-Host "Backspace: Delete"
Write-Host "Enter: Save and exit"
Write-Host "Q: Quit without saving"
"@

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
            # Replace logic
            # You can add logic to replace text
        }
        elseif ($key -eq "`enter") {
            Set-Content -Path $filePath -Value $content
            Write-Host "Saved and exited."
            break
        }
        elseif ($key -eq "q") {
            Write-Host "Exited without saving."
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
    Start-Sleep -Seconds 2
    Exit
  } } else {
    Write-Host "No files are selected`nExiting..."
    Start-Sleep -Seconds 2
    Exit
	} # little edit
}