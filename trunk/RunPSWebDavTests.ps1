Remove-Module pswebdav | out-null
Import-Module ".\pswebdav.psm1"

$baseurl = "http://localhost/dav"

function Get_File 
{
	"" > "$(pwd)\test.txt"
	$localfilename = "$(pwd)\test.txt"
	$status = Get-WebDav "$baseurl/test.zip" $localfilename	
	dir
}

function Get_FileList 
{
	$results = Get-WebDavFileList $baseurl
	$results | ft
}

function Create_Directory 
{	
	$status = New-WebDavDirectory "$baseurl/Test"
	"Directory Created!"
}

function Delete_Directory  
{
	$status = Remove-WebDav "$baseurl/Test"	
	"Directory Deleted!"
}

function Send_File
{
	$status = Send-WebDav "$baseurl/Test/test.txt" "$(pwd)\test.txt"
	"File Uploaded!!!"
}

function Delete_File
{
	$status = Remove-WebDav "$baseurl/Test/test.txt"
	"File Deleted!!!"
}

$quit = $false
while (!$quit)
{
	cls
	"Base URL = $baseurl"
	"1. Get File"
	"2. Get File List"
	"3. Create Directory"
	"4. Delete Directory"
	"5. Send File"
	"6. Delete File"
	"7. Local Dir"
	"8. Unzip File"
	"q = quit"
	[System.Console]::Write("Enter Test #: ")
	$test = [System.Console]::ReadLine()
	switch($test)
	{
		"1" { Get_File }
		"2" { Get_FileList }
		"3" { Create_Directory }
		"4" { Delete_Directory }
		"5" { Send_File }
		"6" { Delete_File }
		"7" { dir }
		"q" { $quit = $true }
	}	
	if ($test -ne "q")
	{
		[System.Console]::Write("Press any key to continue")
		[System.Console]::ReadLine()
	}
}
