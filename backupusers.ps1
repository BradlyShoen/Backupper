$currentDate = Get-Date -Format "MM-dd-yyyy"

$userblacklist = Get-Content "user-blacklist.txt"

$destination = Get-Content "destination.txt"

$folder = Get-Content "folderstobackup.txt"

$computername = gc env:computername
$userprofiles = Get-ChildItem "C:\Users" -directory

$counter = 0

foreach ($userprofile in $userprofiles){
	if($userblacklist -notcontains $userprofile.Name){
		$counter += 1
		foreach ($f in $folder)
		{
			$BackupSource = $userprofile.FullName  + "\" + $f
			$BackupDestination = $destination + "\" + $currentDate + " " + $computername + "\" + $userprofile.Name + "\" + $f
			Copy-Item -ErrorAction SilentlyContinue -recurse -Path  $BackupSource -Destination $BackupDestination
		}
	}
}

Write-Output "`nBacked up $counter profiles"