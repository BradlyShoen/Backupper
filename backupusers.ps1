$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){

    $currentDate = Get-Date -Format "MM-dd-yyyy"

    $destination = Get-Content "$PSScriptRoot\destination.txt"

    $folder = Get-Content "$PSScriptRoot\folderstobackup.txt"

    $userblacklist = Get-Content "$PSScriptRoot\user-blacklist.txt"

    $computername = Get-Content env:computername
    $alluserprofiles = Get-ChildItem "C:\Users" -directory

    $logFileName = Get-Date -format MM-dd-yyyyTHH-mm-ss-ff
    $log = New-Item -Path "$PSScriptRoot\logs" -Name "$logFileName.txt"
    Add-Content $log "Initialized`n"

    function startBackup(){
	    Add-Content $log "`nStarting Backup...`n"
	    $counter = 0
	    $userprofiles = @()

	    $ProgressBar1.value = 0

	    foreach($checkbox in $Checkboxes){
		    if($checkbox.checked -eq $true){
			    $userprofiles += $checkbox.Profile
		    }
	    }

	    $amountOfWorkToDo = $folder.Length * $userprofiles.Length
	    $amountOfWorkDone = 0

	    Add-Content $log "Users to backup: $userprofiles`n"

	    foreach ($userprofile in $userprofiles){
		    $counter += 1
		    foreach ($f in $folder)
		    {
			    Add-Content $log "Backing up $userprofile $f folder..."
			    $BackupSource = $userprofile.FullName  + "\" + $f
			    $BackupDestination = $destination + "\" + $currentDate + " " + $computername + "\" + $userprofile.Name + "\" + $f
			    Add-Content $log "$BackupSource -> $BackupDestination`n"
			    Copy-Item -ErrorAction SilentlyContinue -recurse -Path  $BackupSource -Destination $BackupDestination
			    Start-Sleep -s 1
			    $amountOfWorkDone += 1
			    $ProgressBar1.value = ($amountOfWorkDone/$amountOfWorkToDo)*100
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
	    foreach($checkbox in $checkboxes){
		    $checkbox.checked = $true 
	    }
    }

    function DeselectAllCheckboxes(){
	    foreach($checkbox in $checkboxes){
		    $checkbox.checked = $false 
	    }
    }

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $Backupper                       = New-Object system.Windows.Forms.Form
    $Backupper.ClientSize            = '600,800'
    $Backupper.text                  = "Backupper Version 1.1 By Bradly Shoen"
    $Backupper.TopMost               = $false
    $Backupper.FormBorderStyle = 'Fixed3D'
    $Backupper.MaximizeBox = $false

    $Button1                         = New-Object system.Windows.Forms.Button
    $Button1.text                    = "Select All"
    $Button1.width                   = 108
    $Button1.height                  = 30
    $Button1.location                = New-Object System.Drawing.Point(191,16)
    $Button1.Font                    = 'Microsoft Sans Serif,10'
    $Button1.Add_Click({ SelectAllCheckboxes })

    $Button2                         = New-Object system.Windows.Forms.Button
    $Button2.text                    = "Deselect All"
    $Button2.width                   = 108
    $Button2.height                  = 30
    $Button2.location                = New-Object System.Drawing.Point(301,16)
    $Button2.Font                    = 'Microsoft Sans Serif,10'
    $Button2.Add_Click({ DeselectAllCheckboxes })

    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Location = New-Object System.Drawing.Size(10,50)  
    $groupBox.text = "User Profiles:" 
    $Backupper.Controls.Add($groupBox)

    $Checkboxes = @()
    $maxY = 680
    $y = 20
    $x = 10
    for($i = 0; $i -lt $alluserprofiles.Length; $i++){
        if($userblacklist -notcontains $alluserprofiles[$i].Name){
            $Checkbox = New-Object System.Windows.Forms.CheckBox
            $Checkbox.Text = $alluserprofiles[$i].name
	        $Checkbox.Location = New-Object System.Drawing.Size($x,$y)
	        if($y + 30 -lt $maxY){
		        $y += 30
	        }else{
		        $y = 20
		        $x += 155
	        }
	        $groupbox.Controls.Add($Checkbox) 
	        $Checkbox.Font = 'Microsoft Sans Serif,10'
	        $Checkbox.width = 150
	        $Checkbox.height = 20
	        $Checkbox.AutoSize = $false
	        $Checkbox | Add-Member NoteProperty "Profile" $alluserprofiles[$i]

	        $Checkboxes += $Checkbox
        }
    }
    $groupBox.size = New-Object System.Drawing.Size(580,700)

    $Button3                         = New-Object system.Windows.Forms.Button
    $Button3.text                    = "Start"
    $Button3.width                   = 60
    $Button3.height                  = 30
    $Button3.location                = New-Object System.Drawing.Point(10,755)
    $Button3.Font                    = 'Microsoft Sans Serif,10'
    $Button3.Add_Click({ startBackup })

    $ProgressBar1                    = New-Object system.Windows.Forms.ProgressBar
    $ProgressBar1.width              = 510
    $ProgressBar1.height             = 30
    $ProgressBar1.location           = New-Object System.Drawing.Point(80,755)

    $Backupper.controls.AddRange(@($Button1,$Button2,$Button3,$ProgressBar1))
    $Backupper.ShowDialog()| Out-Null
    $Backupper.Dispose()

}else{
    Write-Host "You must launch Backupper as an Administrator!"
}