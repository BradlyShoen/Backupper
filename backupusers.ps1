<#
    .NOTES
        Created on: 2/7/2020
        Created by: Bradly Shoen
        Version: 1.3
        Organization: University of Montana
        Filename: backupusers.ps1

    .SYNOPSIS
        Creates a backup of user profiles for a Windows machine to a specified location. Must be ran as an administrator.

    .DESCRIPTION
        Lists the user profiles of the Windows machine it is ran on, and allows the user to choose which profiles to back up. The program will then create a 
        folder at the destination found in destination.txt with the following name convention: MM-dd-yyyy computername.  It will then create a folder for each 
        selected user profile and copy the folders found in folderstobackup.txt from each user profile to their respective folders in the destination.
#>

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){

    Get-Content "$PSScriptRoot\config.ini" | foreach-object -begin {$h=@{}} -process { $k = [regex]::split($_,'='); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $h.Add($k[0], $k[1]) } }

    $currentDate = Get-Date -Format "MM-dd-yyyy"

    $destination = $h.Get_Item("DefaultDestination")

    $userblacklist = @("Default","Public","defaultuser0","Administrator")
    $folderblacklist = @("Application Data","Cookies","Local Settings","NetHood","My Documents","PrintHood","Recent","SendTo","Templates","Start Menu")

    $defaultfolders = $h.Get_Item("DefaultFolders") -split ","

    $computername = Get-Content env:computername
    $alluserprofiles = Get-ChildItem "C:\Users" -directory
    $allfolders = Get-ChildItem "C:\Users\Default" -directory -Force

    $logFileName = Get-Date -format MM-dd-yyyyTHH-mm-ss-ff
    $log = New-Item -Path "$PSScriptRoot\logs" -Name "$logFileName.txt"
    
    $launchedUser = (Get-WmiObject -Class win32_computersystem -ComputerName $env:COMPUTERNAME).UserName
    Add-Content $log ($launchedUser + " Initialized`n")

    function startBackup(){
        Add-Content $log "`nStarting Backup...`n"
	    $counter = 0
	    $userprofiles = @()
        $folders = @()

	    $ProgressBar.value = 0

	    foreach($checkbox in $FolderCheckboxes){
		    if($checkbox.checked -eq $true){
			    $folders += $checkbox.Folder
		    }
	    }

        foreach($checkbox in $UserCheckboxes){
		    if($checkbox.checked -eq $true){
			    $userprofiles += $checkbox.Profile
		    }
	    }

	    $amountOfWorkToDo = $folders.Length * $userprofiles.Length
	    $amountOfWorkDone = 0

        Add-Content $log "Users to backup: $userprofiles`n"
        
        if(Test-Path ($DestinationTextbox.Text + "\" + $currentDate + " " + $computername)){
            $computername = $computername + " " + (Get-Date -Format "HHmm")
        }

	    foreach ($userprofile in $userprofiles){
		    $counter += 1
		    foreach ($f in $folders)
		    {
                if($f.name -eq "AppData"){
                    Add-Content $log "Backing up $userprofile $f\Roaming folder..."
			        $BackupSource = $userprofile.FullName  + "\" + $f + "\Roaming"
			        $BackupDestination = $DestinationTextbox.Text + "\" + $currentDate + " " + $computername + "\" + $userprofile.Name + "\" + $f + "\Roaming"
                }else{
                    Add-Content $log "Backing up $userprofile $f folder..."
                    $BackupSource = $userprofile.FullName  + "\" + $f
			        $BackupDestination = $DestinationTextbox.Text + "\" + $currentDate + " " + $computername + "\" + $userprofile.Name + "\" + $f
                }
			    Add-Content $log "$BackupSource -> $BackupDestination`n"
                robocopy $BackupSource $BackupDestination "/E" 
			    Start-Sleep -s 1
			    $amountOfWorkDone += 1
			    $ProgressBar.value = ($amountOfWorkDone/$amountOfWorkToDo)*100
		    }
	    }

        if($counter -eq 1){
	        Write-Host "Successfully backed up $counter profile!"
            Add-Content $log "`nSuccessfully backed up $counter profile"
        }else{
            Write-Host "Successfully backed up $counter profiles!"
            Add-Content $log "`nSuccessfully backed up $counter profiles"
        }
    }

    function SelectAllCheckboxes(){
	    foreach($checkbox in $UserCheckboxes){
		    $checkbox.checked = $true 
	    }
    }

    function DeselectAllCheckboxes(){
	    foreach($checkbox in $UserCheckboxes){
		    $checkbox.checked = $false 
	    }
    }

    function StartRestore(){
        if($RestoreFolderTextbox.text){
            $RestoreDestination = "C:\Users\" + $RestoreProfileTextbox.text
            $RestoreSource = $DestinationTextbox.text + "\" + $RestoreFolderTextbox.text + "\" + $RestoreProfileTextbox.text
            if($RestoreProfileTextbox.text){
                if((Test-Path -Path ("C:\Users\" + $RestoreProfileTextbox.text)) -eq $false){
                    Write-Host ("User has not signed in yet or the profile is incorrect! Check both and try again...")
                    return
                }elseif((Test-Path -Path ($DestinationTextbox.text + "\" + $RestoreFolderTextbox.text)) -eq $false){
                    Write-Host ("Back up folder does not exist! Check name and try again...")
                    return
                }elseif((Test-Path -Path ($DestinationTextbox.text + "\" + $RestoreFolderTextbox.text)) -eq $false){
                    Write-Host ("Specified user was never backed up! Check user profile name and try again...")
                    return
                }else{
                    Add-Content $log ("`nRestoring " + $RestoreSource + " to " + $RestoreDestination)
                    robocopy $RestoreSource $RestoreDestination "/E"
                    Add-Content $log ("Successfully restored " + $RestoreProfileTextbox.text)
                    Write-Host ("Successfully restored the " + $RestoreProfileTextbox.text + " profile!")
                }
            }else{
                $RestoreDestination = "C:\Users\"
                $RestoreSource = $DestinationTextbox.text + "\" + $RestoreFolderTextbox.text

                if((Test-Path -Path ($DestinationTextbox.text + "\" + $RestoreFolderTextbox.text)) -eq $false){
                    Write-Host ("Back up folder does not exist! Check name and try again...")
                    return
                }

                Add-Content $log ("`nRestoring " + $RestoreSource + " to " + $RestoreDestination)
                robocopy $RestoreSource $RestoreDestination "/E"
                Add-Content $log ("Successfully restored all profiles")
                Write-Host ("Successfully restored all profiles!")
            }

        }else{
            Write-Host ("You must specify backed up folder name!")
        }
    }

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $WindowHeight = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.Height - 200
    $WindowWidth = 600

    $Backupper                       = New-Object system.Windows.Forms.Form
    $Backupper.ClientSize            = ''+$WindowWidth.ToString()+','+$WindowHeight.ToString()
    $Backupper.text                  = "Backupper Version 1.2 By Bradly Shoen"
    $Backupper.TopMost               = $false
    $Backupper.FormBorderStyle = 'Fixed3D'
    $Backupper.MaximizeBox = $false

    $Folders                       = New-Object system.Windows.Forms.Form
    $Folders.ClientSize            = '300,400'
    $Folders.text                  = "Select Folders"
    $Folders.TopMost               = $true
    $Folders.FormBorderStyle = 'FixedDialog'
    $Folders.MaximizeBox = $false

    $FoldersLabel = New-Object system.Windows.Forms.Label
    $FoldersLabel.text = "Select the folders to backup:"
    $FoldersLabel.AutoSize = $true
    $FoldersLabel.width = 100
    $FoldersLabel.height = 20
    $FoldersLabel.location = New-Object System.Drawing.Point(10,10)
    $FoldersLabel.Font = 'Microsoft Sans Serif,10'

    $FolderCheckboxes = @()
    $maxY = 380
    $y = 30
    $x = 10
    for($i = 0; $i -lt $allfolders.Length; $i++){
        if($folderblacklist -notcontains $allfolders[$i].Name){
            $Checkbox = New-Object System.Windows.Forms.CheckBox
            $Checkbox.Text = $allfolders[$i].name
            if($Checkbox.Text -eq "AppData"){
                $Checkbox.Text = $Checkbox.Text + " (DANGER)"
            }
	        $Checkbox.Location = New-Object System.Drawing.Size($x,$y)
	        if($y + 30 -lt $maxY){
		        $y += 30
	        }else{
		        $y = 30
		        $x += 120
	        }
	        $Folders.Controls.Add($Checkbox) 
	        $Checkbox.Font = 'Microsoft Sans Serif,10'
	        $Checkbox.width = 180
	        $Checkbox.height = 20
	        $Checkbox.AutoSize = $false
	        $Checkbox | Add-Member NoteProperty "Folder" $allfolders[$i]
            if($defaultfolders -contains $Checkbox.Text){
                $Checkbox.Checked = $true
            }

	        $FolderCheckboxes += $Checkbox
        }
    }

    $Restore                       = New-Object system.Windows.Forms.Form
    $Restore.ClientSize            = '400,200'
    $Restore.text                  = "Restore a Backup"
    $Restore.TopMost               = $true
    $Restore.FormBorderStyle = 'FixedDialog'
    $Restore.MaximizeBox = $false

    $RestoreLabel = New-Object system.Windows.Forms.Label
    $RestoreLabel.text = "Specify backup folder and user profile to restore:"
    $RestoreLabel.AutoSize = $true
    $RestoreLabel.width = 100
    $RestoreLabel.height = 20
    $RestoreLabel.location = New-Object System.Drawing.Point(5,10)
    $RestoreLabel.Font = 'Microsoft Sans Serif,10'

    $RestoreFolderLabel = New-Object system.Windows.Forms.Label
    $RestoreFolderLabel.text = "Folder Name:"
    $RestoreFolderLabel.AutoSize = $true
    $RestoreFolderLabel.width = 78
    $RestoreFolderLabel.height = 20
    $RestoreFolderLabel.location = New-Object System.Drawing.Point(10,46)
    $RestoreFolderLabel.Font = 'Microsoft Sans Serif,10'

    $RestoreFolderTextbox                        = New-Object system.Windows.Forms.TextBox
    $RestoreFolderTextbox.multiline              = $false
    $RestoreFolderTextbox.width                  = 290
    $RestoreFolderTextbox.height                 = 30
    $RestoreFolderTextbox.location               = New-Object System.Drawing.Point(100,44)
    $RestoreFolderTextbox.Font = 'Microsoft Sans Serif,10'

    $RestoreProfileLabel = New-Object system.Windows.Forms.Label
    $RestoreProfileLabel.text = "User Profile:"
    $RestoreProfileLabel.AutoSize = $true
    $RestoreProfileLabel.width = 78
    $RestoreProfileLabel.height = 20
    $RestoreProfileLabel.location = New-Object System.Drawing.Point(10,76)
    $RestoreProfileLabel.Font = 'Microsoft Sans Serif,10'

    $RestoreProfileTextbox                        = New-Object system.Windows.Forms.TextBox
    $RestoreProfileTextbox.multiline              = $false
    $RestoreProfileTextbox.width                  = 290
    $RestoreProfileTextbox.height                 = 30
    $RestoreProfileTextbox.location               = New-Object System.Drawing.Point(100,74)
    $RestoreProfileTextbox.Font = 'Microsoft Sans Serif,10'

    $RestoreDisclaimer = New-Object system.Windows.Forms.Label
    $RestoreDisclaimer.text = "NOTE: Make sure you have the user sign in first before restoring"
    $RestoreDisclaimer.AutoSize = $true
    $RestoreDisclaimer.width = 100
    $RestoreDisclaimer.height = 20
    $RestoreDisclaimer.location = New-Object System.Drawing.Point(10,130)
    $RestoreDisclaimer.Font = 'Microsoft Sans Serif,10'

    $RestoreStart                        = New-Object system.Windows.Forms.Button
    $RestoreStart.text                    = "Restore"
    $RestoreStart.width                   = 380
    $RestoreStart.height                  = 30
    $RestoreStart.location                = New-Object System.Drawing.Point(10,160)
    $RestoreStart.Font                    = 'Microsoft Sans Serif,10'
    $RestoreStart.Add_Click({ StartRestore })

    # This base64 string holds the bytes that make up the icon
    $iconBase64      = 'AAABAAEAICAAAAEAIACoEAAAFgAAACgAAAAgAAAAQAAAAAEAIAAAAAAAAAAAAMMOAADDDgAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAKAAAAEwAAABcBAQAXJycnG1lZWSFubm4jdXV1JXl5eSZ8fHwne3t7KHt7eyh7e3soenp6KHl5eSd5eXkmdnZ2JG1tbSFUVFQdHx8fGAAAABYAAAAXAAAAFwAAA BcAAAAXAAAAFgAAAA4AAAAFAAAAAQAAAAAAAAAAAAAACwAAADYGBgd4DAsMjA4ND4s/P0CVeXl5o4eHh6mLi4uvjo6Os5GRkbeQkJC6j4+QvI6OjruMjIy6jIyNt4yMjLSKioqvhISEqW5ub54uLi+QCwsMigsLDIsLCwyLCwsMigsLDIoMDA2HCQkKYwEBARkAAAACAAAAAAAAAAIAAAAVCgoLfSMjJv EqKS3+Kikt/jc2Ov6Dg4T+mJiY/5WVlf+SkpL/kJCQ/42Njf+JiYn/hYWF/4KCgv+BgYH/gICA/4CAgP+BgYH/cnJy/i0sL/4jIyb+JCQn/iUkJ/4pKCv+KSgs/iopLf0lJSjfBQUFMgAAAAIAAAAAAAAAAQ0NDkYnJireLi0x/y0sMP8uLTD/Pj1B/5mYmf+tra3/n5+f/5qamv+YmJj/mZmZ/5ycnP+ ampr/mJiY/5WVlf+SkpL/kJCQ/4+Pj/9+fn7/MTAz/ycmKf8nJir/JyYp/ywrL/8tLDD/Li0x/ykoLOMGBgYoAAAAAAAAAAAFBQUVKCcqyDEwNP8xMDP/MTAz/zEwNP9BQEP/np6f/6enp/9DQ0T/Li4v/y0tLv9AP0D/mJiZ/6SkpP+goKD/nJyc/5qamv+Xl5f/lZWV/4ODg/82Njj/LCsu/ywrLv8q KS3/MC8y/zIxNP80Mzb/LSwv4QcGBx8AAAAAAAAAAAYGBx4uLTDhNDM3/zQzN/80Mzf/NTQ3/0NCRv+mpab/rayt/zk5PP8mJSj/JCMm/zQzNf+enp7/ra2t/6ioqP+mpqb/o6Oj/5+fn/+dnZ3/i4uM/zw7Pv8yMTT/MTA0/y4tMf8zMjb/ODc6/zg3Ov8yMTTgBwcHHgAAAAAAAAAABwcHHjEwM+A3N jr/NzY6/zc2Ov84Nzr/RURH/6qqqv+0tLT/QkFE/y8uMf8tLC//OTk6/6ampv+2trb/s7Oz/7CwsP+urq7/q6ur/6enp/+UlJX/QkFD/zc2Of82NTj/MjE0/zY1OP87Oj7/Pz5B/zU0OOAHBwgeAAAAAAAAAAAHBwceNDM24Ds6Pf87Oj3/Ozo9/zs6Pf9HRkn/qqqr/7W1tf9EREb/MjE0/y8vMv88PD 3/ra2t/76+vv+5ubn/tra2/7Ozs/+xsbH/r6+v/52dnf9HRkn/Ozo+/zo5PP81NTf/OTg7/z08QP9CQUT/NzY54AgICB4AAAAAAAAAAAcHCB43NjjgPj1B/z49QP8+PUD/Pj1A/0xLTv+tra3/tbW2/0ZFSP8zMzX/MDAy/zs6PP+wsLD/xcXF/8LCwv+/v7//vLy8/7q6uv+3t7f/paWl/0tKTP8/PkH /Pj0//zc3Of88Oz7/Pj1A/z49Qf85ODvgCQgJHgAAAAAAAAAACAgIHjo5POBCQUX/QkFE/0JBRP9CQUT/T05Q/62trf+5ubn/YF9h/1BQUv9OTlD/WFhZ/7a2t//Hx8f/x8fH/8bGxv/FxcX/w8PD/8HBwf+tra7/TUxO/0A/Qv8/P0H/OTg6/z8+Qf9BQET/QUBE/zw7P+AJCQkeAAAAAAAAAAAICAge PTw+4EZFSP9FREf/RURH/0VER/9SUVT/rq6u/8bGxv+9vb7/vLy8/7u7u/+8vLz/xcXF/8bGxv/Gxsb/x8fH/8fHx//Hx8f/x8fH/7W1tf9NTU//QD9C/z8+Qf84Nzr/QkFE/0VER/9FREf/QD9B4AoJCh4AAAAAAAAAAAkICR4/PkHgSUhL/0hHSv9IR0r/SEdK/01MT/+ioqP/wsLC/8HBwf/BwcL/w sHC/8LBwv/BwcH/wcHB/8HBwf/BwcH/wcHB/8HBwf/BwcH/qqqq/0VERv84ODr/NzY5/zU1N/9FREf/SEdK/0hHSv9DQkTgCgoKHgAAAAAAAAAACQkJHkFAQ+BLSk3/SklM/0pJTP9KSUz/SklM/1VUV/9eXV//X19h/2FgY/9jY2X/ZWRn/2dmaP9oZ2n/aGhq/2loav9oZ2n/Z2Zo/2VlZ/9eXV//Tk 1P/0tKTf9JSEr/SEdK/0pJTP9KSUz/SklM/0VERuAKCgseAAAAAAAAAAAJCQkeQ0JF4E1MT/9MS07/TEtO/0xLTv9MS07/S0pN/0tKTf9LSk3/S0pN/0tKTf9LSk3/S0pN/0tKTf9LSk3/S0pN/0tKTf9LSk3/S0pN/0xLTf9MS07/TEtO/0xLTv9MS07/TEtO/0xLTv9MS07/R0ZI4AsLCx4AAAAAAAA AAAkJCh5FREbgT05Q/05NT/9OTVD/Tk1Q/05NUP9OTU//Tk1P/05NT/9OTU//TkxP/01MT/9NTE//TUxP/01MT/9NTE//TUxP/01MT/9OTU//Tk1P/05NT/9OTU//Tk1Q/05NUP9OTVD/Tk1P/05NT/9JSEngCwsLHgAAAAAAAAAACgkKHkZGR+BRUFL/UE9R/1BPUf9NTE7/TEtO/05NT/9PTlH/UVBT /1JRVP9TUlX/VFNV/1RUVv9VVFf/VVRX/1VUVv9UU1b/U1NV/1NSVP9RUVP/UE9S/05OUP9NTE7/TUxO/1BPUf9QT1H/UE9R/0pKS+ALCwseAAAAAAAAAAAKCgoeR0ZJ4FJRVP9RUFP/UE9R/21qaf+XkYv/mJKM/5qUjv+dlpD/npiS/5+Zk/+gmpT/oZuV/6Kblf+im5X/oZqV/6CZk/+fmJL/npeR/ 5yVj/+ak43/mJGK/5eQiv9saWj/T05R/1FQU/9RUFP/TEtN4AwLDB4AAAAAAAAAAAoKCh5JSEvgVFNW/1NSVf9QT1L/mpWR/+zh1P/q39L/6t/T/+rf0v/q39L/6t/S/+re0v/q3tL/6d7R/+ne0f/p3dD/6d3Q/+ndz//p3M//6NzO/+jbzv/o283/6t7Q/5mUj/9QT1H/U1JV/1NSVf9OTU/gDAwMHg AAAAAAAAAACgoKHktKTOBWVVf/VVRW/1JRVP+cl5P/7OLW/+rf1P/q39P/6t/T/+rf0//q39P/6t/T/+nf0//p3tP/6d7S/+ne0v/p3dH/6d3R/+jd0P/o3ND/59zP/+fbzv/q39L/mpWR/1JRU/9VVFb/VVRW/09PUOAMDAweAAAAAAAAAAAKCgoeTExN4FhXWf9XVlj/VFNW/52Zlf/t5Nn/59rN/+b Zy//m2cv/5tnL/+bZy//m2cv/5tnL/+bZyv/l2Mr/5djK/+XYyf/l2Mn/5dfJ/+TXyP/k18j/5djJ/+vh1f+cl5P/VFNV/1dWWP9XVlj/UVBS4AwMDR4AAAAAAAAAAAoKCx5NTU7gWVha/1hXWf9WVVf/n5qX//Do3//x6eL/8Oni//Dp4v/w6eL/8Onh//Dp4f/w6eH/8Onh//Do4P/w6OD/7+ff/+/n 3v/v5t7/7ubd/+7l3P/u5dv/7uXb/52Zlf9VVVf/WFdZ/1hXWf9SUlPgDQ0NHgAAAAAAAAAACwsLHk9OUOBbWlz/Wllb/1hXWf+gnJn/8+zk//Xw6//18Ov/9fDr//Xw6//18Ov/9fDr//Xw6v/18Or/9O/q//Tv6f/07uj/8+7o//Pt5//z7Ob/8uzl//Lr5P/x6N//n5uX/1dXWf9aWVv/Wllb/1RUV eANDQ0eAAAAAAAAAAALCwseUVBS4F1cXv9cW13/Wllb/6Kem//17+j/9vHs//bx6//28ev/9vHr//Xx6//18Ov/9fDr//Xw6v/17+r/9O/p//Tv6f/07uj/8+3n//Pt5v/y7OX/8uzl//Lr4/+hnZr/Wllb/1xbXf9cW13/VlVX4A0NDR4AAAAAAAAAAAsLCx5TUlPgX15g/15dX/9cW13/pKCd//Xw6f /v59//7eTb/+3k2//t5Nv/7eTb/+3k2//t5Nv/7eTa/+3k2v/s49n/7OPZ/+zi2P/s4tj/7OLX/+vh1v/t49n/8+zl/6OfnP9cW13/Xl1f/15dX/9YV1ngDg4OHgAAAAAAAAAACwsLHlRTVOBgX2H/X15g/11cXv+loZ//+fXw//z7+v/8+/n//Pv5//z7+f/8+/n//Pr5//z6+f/8+vj//Pr4//v59// 7+ff/+vj2//r39f/59/T/+fby//n18v/28ev/pKCd/11cXv9fXmD/YF5h/1lYWuAODg4eAAAAAAAAAAAMCwweVVRW4GNiZP9hYGL/X15g/6Win//59fD//v38//79/P/+/fz//v38//79/P/+/fz//v39//7+/f///v7///7+///+/v///v7///7+//7+/f/+/fz//fz7//n08P+lop//X15g/2FgYv9i YGP/W1pc4A4ODh4AAAAAAAAAAAwMDB5VVFbgWllb/1xbXf9hYGL/pqKg//jy7P/69vP/+vXy//r18v/69fL/+vXy//r28v/69vP/+vbz//r29P/79/T/+/f1//v49v/7+Pb//Pn3//z6+P/8+vn/+vby/6ajof9hYGL/Y2Jk/2RjZf9dXF7gDg4PHgAAAAAAAAAADAwMHlNSVOBYWFn/WVha/2JhZP+no 6D/9e7n/+/k3P/t4tj/7eLY/+3i2P/t4tj/7eLY/+3i2P/t49j/7uPZ/+7j2f/u49r/7uTa/+7k2//u5Nv/7uXc//Hp4f/48+7/p6Si/2NiZP9lZGb/ZmVn/15dX+APDg8eAAAAAAAAAAANDA0eWFdY4k5OT/9UU1X/ZWRm/6mkof/48On/+vPu//ry7f/68u3/+vLt//ry7f/68u3/+vPu//vz7v/79O //+/Tw//v18f/89vL//Pfz//z39P/9+PX//vr3//v38v+ppqP/ZWRm/2dmaP9oZ2n/ZGNl4hISEh8AAAAAAAAAAAkICRFZWVmyXFxd4FtbXOBgX2HgkI2K4MnCveDMxsPgzcfE4M3HxODOx8TgzsjF4M/JxeDPycbg0MrG4NDLx+DQy8jg0MvI4NDLyODPy8ngz8vJ4M/LyeDOzMrgy8fD4I+Ni+BfX2D gYGBh4GJhY+BeXl+zDg4OEgAAAAAAAAAAAAAAAAgICBEODg4eDg4OHg0NDR4QEBAeFRQUHhUVFR4WFhUeFxYWHhcWFh4XFhYeFxYWHhcXFh4XFxYeFxcXHhcXFh4XFhYeFhYWHhYWFR4WFRUeFRUVHhUUFB4UFBMeEBAQHg0NDR4NDQ0eDQ0NHgoKChIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA////////////gAf/8AAAB+AAAAfgAAAH4AAAB+AAAAfgAAAH4AAAB+AAAAfgAAAH4AAAB+AAAAfgAAAH4 AAAB+AAAAfgAAAH4AAAB+AAAAfgAAAH4AAAB+AAAAfgAAAH4AAAB+AAAAfgAAAH4AAAB+AAAAf///////////////8='
    $iconBytes       = [Convert]::FromBase64String($iconBase64)
    $stream          = New-Object IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
    $stream.Write($iconBytes, 0, $iconBytes.Length);
    $iconImage       = [System.Drawing.Image]::FromStream($stream, $true)
    $Backupper.Icon       = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())
    $Folders.Icon       = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())

    $FoldersButton                         = New-Object system.Windows.Forms.Button
    $FoldersButton.text                    = "Folders"
    $FoldersButton.width                   = 81
    $FoldersButton.height                  = 30
    $FoldersButton.location                = New-Object System.Drawing.Point(418,16)
    $FoldersButton.Font                    = 'Microsoft Sans Serif,10'
    $FoldersButton.Add_Click({ $Folders.ShowDialog()| Out-Null })

    $RestoreButton                         = New-Object system.Windows.Forms.Button
    $RestoreButton.text                    = "Restore"
    $RestoreButton.width                   = 81
    $RestoreButton.height                  = 30
    $RestoreButton.location                = New-Object System.Drawing.Point(509,16)
    $RestoreButton.Font                    = 'Microsoft Sans Serif,10'
    $RestoreButton.Add_Click({ $Restore.ShowDialog()| Out-Null })

    $DestinationLabel = New-Object system.Windows.Forms.Label
    $DestinationLabel.text = "Backup Destination:"
    $DestinationLabel.AutoSize = $true
    $DestinationLabel.width = 78
    $DestinationLabel.height = 20
    $DestinationLabel.location = New-Object System.Drawing.Point(10,21)
    $DestinationLabel.Font = 'Microsoft Sans Serif,10'

    $DestinationTextbox                        = New-Object system.Windows.Forms.TextBox
    $DestinationTextbox.multiline              = $false
    $DestinationTextbox.width                  = 270
    $DestinationTextbox.height                 = 30
    $DestinationTextbox.location               = New-Object System.Drawing.Point(137,19)
    $DestinationTextbox.Font = 'Microsoft Sans Serif,10'
    $DestinationTextbox.Text = $destination

    $UserProfileBox = New-Object System.Windows.Forms.GroupBox
    $UserProfileBox.Location = New-Object System.Drawing.Size(10,50)  
    $UserProfileBox.text = "User Profiles:" 
    $Backupper.Controls.Add($UserProfileBox)

    $UserCheckboxes = @()
    $maxY = ($WindowHeight-120)
    $y = 50
    $x = 10
    for($i = 0; $i -lt $alluserprofiles.Length; $i++){
        if($userblacklist -notcontains $alluserprofiles[$i].Name){
            $Checkbox = New-Object System.Windows.Forms.CheckBox
            $Checkbox.Text = $alluserprofiles[$i].name
	        $Checkbox.Location = New-Object System.Drawing.Size($x,$y)
	        if($y + 30 -lt $maxY){
		        $y += 30
	        }else{
		        $y = 50
		        $x += 155
	        }
	        $UserProfileBox.Controls.Add($Checkbox) 
	        $Checkbox.Font = 'Microsoft Sans Serif,10'
	        $Checkbox.width = 150
	        $Checkbox.height = 20
	        $Checkbox.AutoSize = $false
	        $Checkbox | Add-Member NoteProperty "Profile" $alluserprofiles[$i]

	        $UserCheckboxes += $Checkbox
        }
    }
    $UserProfileBox.size = New-Object System.Drawing.Size(($WindowWidth-20),($WindowHeight-100))

    $SelectAllButton                         = New-Object system.Windows.Forms.Button
    $SelectAllButton.text                    = "Select All"
    $SelectAllButton.width                   = 108
    $SelectAllButton.height                  = 30
    $SelectAllButton.location                = New-Object System.Drawing.Point(10,15)
    $SelectAllButton.Font                    = 'Microsoft Sans Serif,10'
    $SelectAllButton.Add_Click({ SelectAllCheckboxes })
    $UserProfileBox.Controls.Add($SelectAllButton ) 

    $DeselectAllButton                         = New-Object system.Windows.Forms.Button
    $DeselectAllButton.text                    = "Deselect All"
    $DeselectAllButton.width                   = 108
    $DeselectAllButton.height                  = 30
    $DeselectAllButton.location                = New-Object System.Drawing.Point(120,15)
    $DeselectAllButton.Font                    = 'Microsoft Sans Serif,10'
    $DeselectAllButton.Add_Click({ DeselectAllCheckboxes })
    $UserProfileBox.Controls.Add($DeselectAllButton   ) 

    $StartButton                         = New-Object system.Windows.Forms.Button
    $StartButton.text                    = "Start"
    $StartButton.width                   = 60
    $StartButton.height                  = 30
    $StartButton.location                = New-Object System.Drawing.Point(10,($WindowHeight-45))
    $StartButton.Font                    = 'Microsoft Sans Serif,10'
    $StartButton.Add_Click({ startBackup })

    $ProgressBar                    = New-Object system.Windows.Forms.ProgressBar
    $ProgressBar.width              = $WindowWidth - 90
    $ProgressBar.height             = 30
    $ProgressBar.location           = New-Object System.Drawing.Point(80,($WindowHeight-45))

    $Backupper.controls.AddRange(@($StartButton,$ProgressBar,$DestinationLabel,$DestinationTextbox,$FoldersButton,$RestoreButton))
    $Folders.controls.AddRange(@($FoldersLabel))
    $Restore.controls.AddRange(@($RestoreLabel,$RestoreDisclaimer,$RestoreFolderLabel,$RestoreFolderTextbox,$RestoreProfileLabel,$RestoreProfileTextbox,$RestoreStart,$RestoreProgressBar))
    $Backupper.ShowDialog()| Out-Null
    $Backupper.Dispose()
    $Folders.Dispose()

}else{
    Write-Host "You must launch Backupper as an Administrator!"
}