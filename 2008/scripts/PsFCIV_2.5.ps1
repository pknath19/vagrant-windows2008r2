#####################################################################
# PsFCIV_2.0.ps1
# Version 2.5
#
# File Checksum Integrity Verifier - PowerShell native version
#
# Note: requires PowerShell V2, not compatible with PowerShell 1.0
# Reference links:
# http://support.microsoft.com/kb/841290
# http://gallery.technet.microsoft.com/PowerShell-File-Checksum-e57dcd67
#
# Vadims Podans (c) 2009 - 2014
# http://en-us.sysadmins.lv/
#####################################################################
#requires -Version 2.0

function Start-PsFCIV {
<#
.Synopsis
	Checks files integrity. File Checksum Integreity Verifier (FCIV) compatible version.
.Description
	This command calculates hashes for each file and stores this information in an XML
	database. Once the database is created, the command can check file integrity against database.
	
	Script can use PsFCIV and native FCIV database formats.
.Parameter Path
	Specifies the path to folder that contains files to be verified by the script.
.Parameter XML
	Specifies the path to the XML database that stores information about files.
	If database does not exist, the script will create it. The path can be absolute or
	relative. If the path is relative, the database must be placed in the root folder of Path parameter.
.Parameter Include
	Specifies the file to check. If specified, only this file will be checked during execution.
.Parameter Exclude
	Speicifes the file or files to exclude from check. The XML database is excluded by default.
.Parameter Action
	Specifies the action for files with inconsistent length, modification date/time or hash mismatch.
	Possible values are Rename or Delete. If Rename is specified, the script will add .BAD
	extension to a file name.
.Parameter Show
	Specifies file group that will be shown based on some criteria in graphic Out-GridView window.
	Possible values are: New, Ok, Bad, Missed, Unknown and Locked. You can combine these values.
	Additionally, selected file groups are stored in a global variable: $global:stats and can be used
	for afterward processing.
	Please note, to use this parameter you need .Net Framework 3.5 SP1 (or newer) installed.
	
	Note: this parameter has no effect if 'NoStatistic' switch parameter is specified.
.Parameter HashAlgorithm
	Specifies the hash algorithm to use. Can be one (or combination) of the following
	algorithms: MD5, SHA1, SHA256, SHA384, SHA512.
	
	Algorithms can be combined only when you create a new XML file. In this case each file is
	hashed by using every algorithm  specified. If no algorithm is specified, SHA1 is used as
	the default algorithm.
	
	If more than one algorithm is specified during file checking, then only the first algorithm is used.
	If no algorithm is specified  then the strongest algorithm is used for a particular file. For example,
	an entry in XML database contains hashes for SHA1 and SHA256, another entry has only MD5 hash. In this case SHA256
	is used for the first file and MD5 for another file. The strongest algorithm is determined automatically.
.Parameter Recurse
	Specifies whether the script should check files in subfolders. 
.Parameter Rebuild
	Recreates the XML database without checking files. If files listed in the XML are not present in the target location
	this switch will remove these entries from database. And if there are new files
	this switch will add entries to the database for these files.
.Parameter NoStatistics
	Instrusts the command to not store detailed statistics per each file. This switch improves
	script performance.
.Parameter Quiet
	When script finishes the job, it exitss the PowerShell session with a numeric exit code.
	The exit codes are described in Outputs section
.Parameter Online
	Performs file hash calculation and passes output to the pipeline. When this switch is set to
	True, XML database is not used. This switch is useful when you just need to calculate hashes over
	a set of files.
.Example
	PS C:\> Start-PsFCIV -Path C:\tmp -XML DB.XML

	Checks all files in C:\tmp folder by using SHA1 hash algorithm.
.Example
	PS C:\> Start-PsFCIV -Path C:\tmp -XML DB.XML -HashAlgorithm SHA1, SHA256, SHA512 -Recurse

	Checks all files in C:\tmp folder and subfolders by using SHA1, SHA256 and SHA512 algorithms
.Example
	PS C:\> Start-PsFCIV -Path C:\tmp -Include *.txt -XML DB.XML -HashAlgorithm SHA512
	
	Checks all TXT files in C:\tmp folder by using SHA512 hash algorithm.
.Example
	PS C:\> Start-PsFCIV -Path C:\tmp -XML DB.XML -Rebuild
	
	Rebuilds DB file, by removing all unused entries (when an entry exists, but
	the file does not exist) from the XML file and add all new files that has no records in the XML file
	using SHA1 algorithm. Existing files are not checked for integrity consistence.
.Example
	PS C:\> Start-PsFCIV -Path C:\tmp -XML DB.XML -HashAlgorithm SHA256 -Action Rename
	
	Checks all files in C:\tmp folder using SHA256 algorithm and renames files
	with Length, LastWriteTime or hash mismatch by adding .BAD extension to them.
	The 'Delete' action can be appended to delete all bad files.
.Example
	PS C:\> Start-PsFCIV -Path C:\tmp -XML DB.XML -Show Ok, Bad
	
	Checks all files in C:\tmp folder using SHA1 algorithm and shows
	filenames that match Ok or Bad category.
.Example
	PS C:\> Start-PsFCIV -Path C:\temp -HashAlgorithm SHA1, SHA256, SHA512 -Online
	
	Performs file hash calulation and passes the output objects to a pipeline without
	using a XML database
.Outputs
	The script can return different output depending on the -Quiet switch. If the switch is passed,
	the script doesn't return anything to the console window and generates ExitCode depending on
	file check results. This is the list of possible exitcodes:
	
	0 - all files are ok
	1 - there are bad files
	2 - there are missing files
	4 - there are files with Unknown status
	8 - there are locked and unchecked files
	2147483647 - Rebuild mode
	
	exit codes can be combined by using bitwise OR operator.
	
	if -Quiet switch is not present, the script generates general statistics about
	checked files, such as total processed files count, total files with
	Good, Bad, Locked, Missed, New, Unnown status.
.Link
    http://support.microsoft.com/kb/841290
.Link
	http://www.sysadmins.lv/PermaLink,guid,22a8186c-615b-41fa-8062-d74e1a2a28e0.aspx
.Link
	http://www.sysadmins.lv/PermaLink,guid,29898a6c-aceb-4738-82d8-318bc89272cc.aspx
#>
[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[IO.DirectoryInfo]$Path,
		[Parameter(Mandatory = $true, Position = 1, ParameterSetName = '__xml')]
		[string]$XML,
		[Parameter(Position = 2)]
		[string]$Include = "*.*",
		[Parameter(Position = 3)]
		[string[]]$Exclude,
		[ValidateSet("Rename", "Delete")]
		[string]$Action,
		[ValidateSet("Bad", "Locked", "Missed", "New", "Ok", "Unknown", "All")]
		[String[]]$Show,
		[ValidateSet("MD5", "SHA1", "SHA256", "SHA384", "SHA512")]
		[AllowEmptyCollection()]
		[String[]]$HashAlgorithm = "SHA1",
		[switch]$Recurse,
		[switch]$Rebuild,
		[switch]$Quiet,
		[switch]$NoStatistic,
		[Parameter(ParameterSetName = '__online')]
		[switch]$Online
	)

#region C# wrappers
Add-Type @"
using System;
using System.Collections.Generic;
using System.Xml.Serialization;
namespace PsFCIV {
	public class StatTable {
		public List<String> Total = new List<String>();
		public List<String> New = new List<String>();
		public List<String> Ok = new List<String>();
		public List<String> Bad = new List<String>();
		public List<String> Missed = new List<String>();
		public List<String> Locked = new List<String>();
		public List<String> Unknown = new List<String>();
		public int Del;
	}
	public class IntStatTable {
		public Int32 Total;
		public Int32 New;
		public Int32 Ok;
		public Int32 Bad;
		public Int32 Missed;
		public Int32 Locked;
		public Int32 Unknown;
		public Int32 Del;
	}
	[XmlType(AnonymousType = true)]
	[XmlRoot(Namespace = "", IsNullable = false)]
	public class FCIV {
		public FCIV() { FILE_ENTRY = new List<FCIVFILE_ENTRY>(); }
		
		[XmlElement("FILE_ENTRY")]
		public List<FCIVFILE_ENTRY> FILE_ENTRY { get; set; }
	}
	[XmlType(AnonymousType = true)]
	public class FCIVFILE_ENTRY {
		public FCIVFILE_ENTRY() { }
		public FCIVFILE_ENTRY(string path) { name = path; }

		public String name { get; set; }
		public UInt32 Size { get; set; }
		public String TimeStamp { get; set; }
		public String MD5 { get; set; }
		public String SHA1 { get; set; }
		public String SHA256 { get; set; }
		public String SHA384 { get; set; }
		public String SHA512 { get; set; }

		public override Int32 GetHashCode() { return name.GetHashCode(); }
		public override Boolean Equals(Object other) {
			if (ReferenceEquals(null, other) || other.GetType() != GetType()) { return false; }
			return other.GetType() == GetType() && String.Equals(name, ((FCIVFILE_ENTRY)other).name);
		}
	}
}
"@ -Debug:$false -Verbose:$false -ReferencedAssemblies "System.Xml"
Add-Type -AssemblyName System.Xml
#endregion
	
	if ($PSBoundParameters.Verbose) {$VerbosePreference = "continue"}
	if ($PSBoundParameters.Debug) {$DebugPreference = "continue"}
	$oldverb = $host.PrivateData.VerboseForegroundColor
	$olddeb = $host.PrivateData.DebugForegroundColor
	# preserving current path
	$oldpath = $pwd.Path
	$Exclude += $XML

	if (Test-Path -LiteralPath $path) {
		Set-Location -LiteralPath $path
		if ($pwd.Provider.Name -ne "FileSystem") {
			Set-Location $oldpath
			throw "Specified path is not filesystem path. Try again!"
		}
	} else {throw "Specified path not found."}
	
	# statistic variables
	$sum = $new = New-Object PsFCIV.FCIV
	# creating statistics variable with properties. Each property will contain file names (and paths) with corresponding status.
	$global:stats = New-Object PsFCIV.StatTable
	$script:statcount = New-Object PsFCIV.IntStatTable
	
	# lightweight proxy function for Get-ChildItem cmdlet
	function dirx ([string]$Path, [string]$Filter, [string[]]$Exclude, $Recurse, [switch]$Force) {
		Get-ChildItem @PSBoundParameters -ErrorAction SilentlyContinue | Where-Object {!$_.psiscontainer}
	}	
	# internal function that will check whether the file is locked. All locked files are added to a group with 'Unknown' status.
	function __filelock ($file) {
		$locked = $false
		trap {Set-Variable -name locked -value $true -scope 1; continue}
		$inputStream = New-Object IO.StreamReader $file.FullName
		if ($inputStream) {$inputStream.Close()}
		if ($locked) {
			$host.PrivateData.VerboseForegroundColor = "Yellow"
			$host.PrivateData.DebugForegroundColor = "Yellow"
			Write-Verbose "File $($file.Name) is locked. Skipping this file.."
			Write-Debug "File $($file.Name) is locked. Skipping this file.."
			__statcounter $filename Locked
		}
		$locked
	}	
	# internal function to generate UI window with results by using Out-GridView cmdlet.
	function __formatter ($props, $max) {
		$total = @($input)
		foreach ($property in $props) {
			$(for ($n = 0; $n -lt $max; $n++) {
				$total[0] | Select-Object @{n = $property; e = {$_.$property[$n]}}
			}) | Out-GridView -Title "File list by category: $property"
		}
	}
	# internal hasher
	function __hashbytes ($type, $file) {
		$hasher = [Security.Cryptography.HashAlgorithm]::Create($type)
		$inputStream = New-Object IO.StreamReader $file.FullName
		$hashBytes = $hasher.ComputeHash($inputStream.BaseStream)
		$hasher.Clear()
		$inputStream.Close()
		$hashBytes
	}
	# internal function which reads the XML file (if exist).
	function __fromxml ($xml) {
	# reading existing XML file and selecting required properties
		if (!(Test-Path -LiteralPath $XML)) {return New-Object PsFCIV.FCIV}
		try {
			$fs = New-Object IO.FileStream $XML, "Open"
			$xmlser = New-Object System.Xml.Serialization.XmlSerializer ([Type][PsFCIV.FCIV])
			$sum = $xmlser.Deserialize($fs)
			$fs.Close()
			$sum
		} catch {
			Write-Error -Category InvalidData -Message "Input XML file is not valid FCIV XML file."
		} finally {
			if ($fs -ne $null) {$fs.Close()}
		}
		
	}
	# internal xml writer
	function __writexml ($sum) {
		if ($sum.FILE_ENTRY.Count -eq 0) {
			$host.PrivateData.VerboseForegroundColor = "Yellow"
			$host.PrivateData.DebugForegroundColor = "Yellow"
			Write-Verbose "There is no data to write to XML database."
			Write-Debug "There is no data to write to XML database."
		} else {
			$host.PrivateData.DebugForegroundColor = "Cyan"
			Write-Debug "Preparing to DataBase file creation..."
			try {
				$fs = New-Object IO.FileStream $XML, "Create"
				$xmlser = New-Object System.Xml.Serialization.XmlSerializer ([Type][PsFCIV.FCIV])
				$xmlser.Serialize($fs,$sum)
			} finally {
				if ($fs -ne $null) {$fs.Close()}
			}
			Write-Debug "DataBase file created..."
		}
	}
	# internal function to create XML entry object for a file.
	function __makeobject ($file, [switch]$NoHash, [switch]$hex) {
		$host.PrivateData.DebugForegroundColor = "Yellow"
		Write-Debug "Starting object creation for '$($file.FullName)'..."
		$object = New-Object PsFCIV.FCIVFILE_ENTRY
		$object.name = $file.FullName -replace [regex]::Escape($($pwd.ProviderPath + "\"))
		$object.Size = $file.Length
		# use culture-invariant date/time format.
		$object.TimeStamp = "$($file.LastWriteTime.ToUniversalTime())"
		if (!$NoHash) {
		# calculating appropriate hash and convert resulting byte array to a Base64 string
			foreach ($hash in "MD5", "SHA1", "SHA256", "SHA384", "SHA512") {
				if ($HashAlgorithm -contains $hash) {
					Write-Debug "Calculating '$hash' hash..."
					$hashBytes = __hashbytes $hash $file
					if ($hex) {
						$object.$hash = -join ($hashBytes | Foreach-Object {"{0:X2}" -f $_})
					} else {
						Write-Debug ("Calculated hash value: " + (-join ($hashBytes | Foreach-Object {"{0:X2}" -f $_})))
						$object.$hash = [System.Convert]::ToBase64String($hashBytes)
					}
				}
			}
		}
		Write-Debug "Object created!"
		$object
	}	
	# internal function that calculates current file hash and formats it to an octet string (for example, B926D7416E8235E6F94F756E9F3AE2F33A92B2C4).
	function __precheck ($entry, $file, $HashAlgorithm) {
		$host.PrivateData.DebugForegroundColor = "Yellow"
		if ($HashAlgorithm.Length -gt 0) {
			$SelectedHash = $HashAlgorithm
		} else {
			:outer foreach ($hash in "SHA512", "SHA384", "SHA256", "SHA1", "MD5") {
				if ($entry.$hash) {$SelectedHash = $hash; break outer}
			}
		}
		$host.PrivateData.DebugForegroundColor = "Green"
		Write-Debug "Selected hash: $hash"
		-join ($(__hashbytes $SelectedHash $file) | ForEach-Object {"{0:X2}" -f $_})
		$SelectedHash
	}
	# process -Action parameter to perform an action against bad file (if actual file properties do not match the record in XML).
	function __takeaction ($file, $Action) {
		switch ($Action) {
			"Rename" {Rename-Item $file $($file.FullName + ".bad")}
			"Delete" {Remove-Item $file -Force}
		}
	}	
	# core file verification function.
	function __checkfiles ($entry, $file, $Action) {
		if (($file.Length -eq $entry.Size) -and ("$($file.LastWriteTime.ToUniversalTime())" -eq $entry.TimeStamp)) {
			$hexhash = __precheck $entry $file $HashAlgorithm
			$ActualHash = -join ([Convert]::FromBase64String($entry.($hexhash[1])) | ForEach-Object {"{0:X2}" -f $_})
			if (!$ActualHash) {
				$host.PrivateData.VerboseForegroundColor = "Red"
				Write-Verbose "XML database entry does not contains '$($hexhash[1])' hash value for the entry '$($entry.name)'."
				__statcounter $entry.name Unknown
				return
			} elseif ($ActualHash -eq $hexhash[0]) {
				$host.PrivateData.VerboseForegroundColor = $Host.PrivateData.DebugForegroundColor = "Green"
				Write-Debug "File hash: $ActualHash"
				Write-Verbose "File '$($file.name)' is ok."
				__statcounter $entry.name Ok
				return
			} else {
				$host.PrivateData.DebugForegroundColor = "Red"
				Write-Debug "File '$($file.name)' failed hash verification.
					Expected hash: $hexhash
					Actual hash: $ActualHash"
				__statcounter $entry.name Bad
				if ($Action) {__takeaction $file $Action}
			}
		} else {
			$host.PrivateData.VerboseForegroundColor = $Host.PrivateData.DebugForegroundColor = "Red"
			Write-Verbose "File '$($file.FullName)' size or Modified Date/Time mismatch."
			Write-Debug "Expected file size is: $($entry.Size) byte(s), actual size is: $($file.Length) byte(s)."
			Write-Debug "Expected file modification time is: $($entry.TimeStamp), actual file modification time is: $($file.LastWriteTime.ToUniversalTime())"
			__statcounter $entry.name Bad
			if ($Action) {__takeaction $file $Action}
		}
	}
	# internal function to calculate resulting statistics and show if if necessary.	
	function __stats {
	# if -Show parameter is presented we display selected groups (Total, New, Ok, Bad, Missed, Unknown)
		if ($show -and !$NoStatistic) {
			if ($Show -eq "All" -or $Show.Contains("All")) {
				$global:stats | __formatter "Bad", "Locked", "Missed", "New", "Ok", "Unknown" $script:statcount.Total
			} else {
				$global:stats | Select-Object $show | __formatter $show $script:statcount.Total
			}			
		}
		# script work in numbers
		if (!$Quiet) {
			Write-Host ----------------------------------- -ForegroundColor Green
			if ($Rebuild) {
				Write-Host Total entries processed: $script:statcount.Total -ForegroundColor Cyan
				Write-Host Total removed unused entries: $script:statcount.Del -ForegroundColor Yellow
			} else {Write-Host Total files processed: $script:statcount.Total -ForegroundColor Cyan}
			Write-Host Total new added files: $script:statcount.New -ForegroundColor Green
			Write-Host Total good files: $script:statcount.Ok -ForegroundColor Green
			Write-Host Total bad files: $script:statcount.Bad -ForegroundColor Red
			Write-Host Total unknown status files: $script:statcount.Unknown -ForegroundColor Yellow
			Write-Host Total missing files: $script:statcount.Missed -ForegroundColor Yellow
			Write-Host Total locked files: $script:statcount.Locked -ForegroundColor Yellow
			Write-Host ----------------------------------- -ForegroundColor Green
		}
		# restore original variables
		Set-Location -LiteralPath $oldpath
		$host.PrivateData.VerboseForegroundColor = $oldverb
		$host.PrivateData.DebugForegroundColor = $olddeb
		$exit = 0
		# create exit code depending on check status
		if ($Rebuild) {$exit = [int]::MaxValue} else {
			if ($script:statcount.Bad -ne 0) {$exit += 1}
			if ($script:statcount.Missed -ne 0) {$exit += 2}
			if ($script:statcount.Unknown -ne 0) {$exit += 4}
			if ($script:statcount.Locked -ne 0) {$exit += 8}
		}
		if ($Quiet) {exit $exit}
	}
	# internal function to update statistic counters.
	function __statcounter ($filename, $status) {
		$script:statcount.$status++
		$script:statcount.Total++
		if (!$NoStatistic) {
			$global:stats.$status.Add($filename)
		}
	}
	if ($Online) {
		$host.PrivateData.DebugForegroundColor = "White"
		Write-Debug "Online mode ON"
		dirx -Path .\*.* -Filter $Include -Exclude $Exclude $Recurse -Force | ForEach-Object {
			$host.PrivateData.VerboseForegroundColor = $Host.UI.RawUI.ForegroundColor
			Write-Verbose "Perform file '$($_.fullName)' checking."
			$file = Get-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
			if (__filelock $file) {return}
			__makeobject $file -hex
		}
		return
	}

	<#
	in this part we perform XML file update by removing entries for non-exist files and
	adding new entries for files that are not in the database.
	#>
	if ($Rebuild) {
		$host.PrivateData.DebugForegroundColor = "White"
		Write-Debug "Rebuild mode ON"
		if (Test-Path -LiteralPath $xml) {
			$old = __fromxml $xml
		} else {
			Set-Location $oldpath
			throw "Unable to find XML file. Please, run the command without '-Rebuild' switch."
		}
		$interm = New-Object PsFCIV.FCIV
		# use foreach-object instead of where-object to keep original types.
		$host.PrivateData.VerboseForegroundColor = $host.UI.RawUI.ForegroundColor
		Write-Verbose "Perform DB file cleanup from non-existent items."
		$old.FILE_ENTRY | ForEach-Object {
			if ((Test-Path -LiteralPath $_.name)) {
				if ($_.name -eq $xml) {
					$host.PrivateData.DebugForegroundColor = "Yellow"
					Write-Debug "File '$($_.name)' is DB file. Removed."
				} else {
					$interm.FILE_ENTRY.Add($_)
				}
			} else {
				$host.PrivateData.DebugForegroundColor = "Yellow"
				Write-Debug "File '$($_.name)' does not exist. Removed."
			}
		}
		$script:statcount.Del = $old.FILE_ENTRY.Count - $interm.Length
		$script:statcount.Total = $old.FILE_ENTRY.Count - $interm.Length
		dirx -Path .\*.* -Filter $Include -Exclude $Exclude $Recurse -Force | ForEach-Object {
			$host.PrivateData.VerboseForegroundColor = $host.UI.RawUI.ForegroundColor
			Write-Verbose "Perform file '$($_.FullName)' checking."
			$file = Get-Item -LiteralPath $_.FullName -Force
			if (__filelock $file) {return}
			$filename = $file.FullName -replace [regex]::Escape($($pwd.providerpath + "\"))
			$host.PrivateData.VerboseForegroundColor = "Green"
			if ($interm.FILE_ENTRY.Contains((New-Object PsFCIV.FCIVFILE_ENTRY $filename))) {
				Write-Verbose "File '$filename' already exist in XML database. Skipping."
				return
			} else {
				$new.FILE_ENTRY.Add((__makeobject $file))
				Write-Verbose "File '$filename' is added."
				__statcounter $filename New
			}
		}
		$interm.FILE_ENTRY.AddRange($new.FILE_ENTRY)
		__writexml $interm
		__stats
		return
	}
	
	# this part contains main routine
	$sum = __fromxml $xml
	<#
	check XML file format. If Size property of the first element is zero, then the file was generated by
	original FCIV.exe tool. In this case we transform existing XML to a new PsFCIV format by adding new
	properties. Each record is checked against hashes stored in the source XML file. If hash check fails,
	an item is removed from final XML.
	#>
	if ($sum.FILE_ENTRY.Count -gt 0 -and $sum.FILE_ENTRY[0].Size -eq 0) {
		# 
		if ($PSBoundParameters["HashAlgorithm"]) {$HashAlgorithm = $HashAlgorithm[0].ToUpper()} else {$HashAlgorithm = @()}
		$host.PrivateData.DebugForegroundColor = "White"
		Write-Debug "FCIV (compatibility) mode ON"
		if ($HashAlgorithm -and $HashAlgorithm -notcontains "sha1" -and $HashAlgorithm -notcontains "md5") {
			throw "Specified hash algorithm (or algorithms) is not supported. For native FCIV source, use MD5 and/or SHA1."
		}
		for ($index = 0; $index -lt $sum.FILE_ENTRY.Count; $index++) {
			$host.PrivateData.VerboseForegroundColor = $host.UI.RawUI.ForegroundColor
			Write-Verbose "Perform file '$($sum.FILE_ENTRY[$index].name)' checking."
			$filename = $sum.FILE_ENTRY[$index].name
			# check if the path is absolute and matches current path. If the path is absolute and does not belong to
			# current path -- skip this entry.
			if ($filename.Contains(":") -and $filename -notmatch [regex]::Escape($pwd.ProviderPath)) {return}
			# if source file name record contains absolute path, and belongs to the current pathe,
			# just strip base path. New XML format uses relative paths only.
			if ($filename.Contains(":")) {$filename = $filename -replace ([regex]::Escape($($pwd.ProviderPath + "\")))}
			# Test if the file exist. If the file does not exist, skip the current entry and process another record.
			if (!(Test-Path -LiteralPath $filename)) {
				$host.PrivateData.VerboseForegroundColor = "Yellow"
				Write-Verbose "File '$filename' not found. Skipping."
				__statcounter $filename Missed
				return
			}
			# get file item and test if it is not locked by another application
			$file = Get-Item -LiteralPath $filename -Force -ErrorAction SilentlyContinue
			if (__filelock $file) {return}
			# create new-style entry record that stores additional data: file length and last modification timestamp.
			$entry = __makeobject $file -NoHash
			$entry.name = $filename
			# process current hash entries and copy required hash values to a new entry object.
			"SHA1", "MD5" | ForEach-Object {$entry.$_ = $sum.FILE_ENTRY[$index].$_}
			$sum.FILE_ENTRY[$index] = $entry
			__checkfiles $newentry $file $Action
		}
		# we are done. Overwrite XML, display stats and exit.
		__writexml $sum
		# display statistics and exit right now.
		__stats
	}
	# if XML file exist, proccess and check all records. XML file will not be modified.
	if ($sum.FILE_ENTRY.Count -gt 0) {
		$host.PrivateData.DebugForegroundColor = "White"
		Write-Debug "Native PsFCIV mode ON"
		# this part is executed only when we want to process certain file. Wildcards are not allowed.
		if ($Include -ne "*.*") {
			$sum.FILE_ENTRY | Where-Object {$_.name -like $Include} | ForEach-Object {
				$host.PrivateData.VerboseForegroundColor = $host.UI.RawUI.ForegroundColor
				Write-Verbose "Perform file '$($_.name)' checking."
				$entry = $_
				# calculate the hash if the file exist.
				if (Test-Path -LiteralPath $entry.name) {
					# and check file integrity
					$file = Get-Item -LiteralPath $entry.name -Force -ErrorAction SilentlyContinue
					__checkfiles $entry $file $Action
				} else {
					# if there is no record for the file, skip it and display appropriate message
					$host.PrivateData.VerboseForegroundColor = "Yellow"
					Write-Verbose "File '$filename' not found. Skipping."
					__statcounter $entry.name Missed
				}
			}
		} else {
			$sum.FILE_ENTRY | ForEach-Object {
				<#
				to process files only in the current directory (without subfolders), we remove items
				that contain slashes from the process list and continue regular file checking.
				#>
				if (!$Recurse -and $_.name -match "\\") {return}
				$host.PrivateData.VerboseForegroundColor = $host.UI.RawUI.ForegroundColor
				Write-Verbose "Perform file '$($_.name)' checking."
				$entry = $_
				if (Test-Path -LiteralPath $entry.name) {
					$file = Get-Item -LiteralPath $entry.name -Force -ErrorAction SilentlyContinue
					__checkfiles $entry $file $Action
				} else {
					$host.PrivateData.VerboseForegroundColor = "Yellow"
					Write-Verbose "File '$($entry.name)' not found. Skipping."
					__statcounter $entry.name Missed
				}
			}
		}
	} else {
		# if there is no existing XML DB file, start from scratch and create a new one.
		$host.PrivateData.DebugForegroundColor = "White"
		Write-Debug "New XML mode ON"

		dirx -Path .\*.* -Filter $Include -Exclude $Exclude $Recurse -Force | ForEach-Object {
			$host.PrivateData.VerboseForegroundColor = $Host.UI.RawUI.ForegroundColor
			Write-Verbose "Perform file '$($_.fullName)' checking."
			$file = Get-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
			if (__filelock $file) {return}
			$entry = __makeobject $file
			$sum.FILE_ENTRY.Add($entry)
			__statcounter $entry.name New
		}
		__writexml $sum
	}
	__stats
}

# SIG # Begin signature block
# MIIT6wYJKoZIhvcNAQcCoIIT3DCCE9gCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUrW4awDHY2p46D9dizfv1FB2N
# mwqggg8hMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggaEMIIFbKADAgECAhAPQeJuTPcULjW7alEtlqslMA0GCSqGSIb3DQEBBQUAMG8x
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURpZ2lDZXJ0IEFzc3VyZWQgSUQgQ29k
# ZSBTaWduaW5nIENBLTEwHhcNMTMxMTExMDAwMDAwWhcNMTUwMzEyMTIwMDAwWjBQ
# MQswCQYDVQQGEwJMVjENMAsGA1UEBxMEUmlnYTEYMBYGA1UEChMPU3lzYWRtaW5z
# IExWIElLMRgwFgYDVQQDEw9TeXNhZG1pbnMgTFYgSUswggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCtw9BW44GJuoGHLv7baBr8p+mxspoTTjNr4ECCsdZS
# 4u9jdzMlLkMCUilUZplfu0vzXmScshBZViCL0kKo+8wS0KnqIGDUD3gGZBbCFJhp
# cdH7a+SYxdTtq4fbA9DrvcE8iWmfs2+SvDlGstcOTM5PlJV9G4j56xP8+Mnr0i3R
# xXtWun3gTIQFJRi4VbIWQYkLwOcNn9t+CNyuqbGgwB6lhSEuE5G+Ckhy9JWaQ860
# YOTNFE5maeCb4h78TAFzpIZQhNLunVGifHKLyg3JvzrJ8k0uLe32MCgIwIJfGc46
# U85myyP1azolKAF0coMUByOCCvu2D5Qd4sU/nsF6tq8HAgMBAAGjggM5MIIDNTAf
# BgNVHSMEGDAWgBR7aM4pqsAXvkl64eU/1qf3RY81MjAdBgNVHQ4EFgQU5+q8k9QB
# lSStwXcPPHv9OE4FWqMwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUF
# BwMDMHMGA1UdHwRsMGowM6AxoC+GLWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9h
# c3N1cmVkLWNzLTIwMTFhLmNybDAzoDGgL4YtaHR0cDovL2NybDQuZGlnaWNlcnQu
# Y29tL2Fzc3VyZWQtY3MtMjAxMWEuY3JsMIIBxAYDVR0gBIIBuzCCAbcwggGzBglg
# hkgBhv1sAwEwggGkMDoGCCsGAQUFBwIBFi5odHRwOi8vd3d3LmRpZ2ljZXJ0LmNv
# bS9zc2wtY3BzLXJlcG9zaXRvcnkuaHRtMIIBZAYIKwYBBQUHAgIwggFWHoIBUgBB
# AG4AeQAgAHUAcwBlACAAbwBmACAAdABoAGkAcwAgAEMAZQByAHQAaQBmAGkAYwBh
# AHQAZQAgAGMAbwBuAHMAdABpAHQAdQB0AGUAcwAgAGEAYwBjAGUAcAB0AGEAbgBj
# AGUAIABvAGYAIAB0AGgAZQAgAEQAaQBnAGkAQwBlAHIAdAAgAEMAUAAvAEMAUABT
# ACAAYQBuAGQAIAB0AGgAZQAgAFIAZQBsAHkAaQBuAGcAIABQAGEAcgB0AHkAIABB
# AGcAcgBlAGUAbQBlAG4AdAAgAHcAaABpAGMAaAAgAGwAaQBtAGkAdAAgAGwAaQBh
# AGIAaQBsAGkAdAB5ACAAYQBuAGQAIABhAHIAZQAgAGkAbgBjAG8AcgBwAG8AcgBh
# AHQAZQBkACAAaABlAHIAZQBpAG4AIABiAHkAIAByAGUAZgBlAHIAZQBuAGMAZQAu
# MIGCBggrBgEFBQcBAQR2MHQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBMBggrBgEFBQcwAoZAaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0QXNzdXJlZElEQ29kZVNpZ25pbmdDQS0xLmNydDAMBgNVHRMBAf8E
# AjAAMA0GCSqGSIb3DQEBBQUAA4IBAQA3vEtKvZ6tq2N9zv6WrbMMsgUDqicenbOi
# mISSeJoYuBJlaYaetBrnJu6LgWMECO3lwaJckSDvhe8aOtUqamWaTwKLCXU8MXdX
# ERJlkehw8V0rJjPWlGjs86zwfNz1JUj74p9GCdly+1p0lpx7V26yf1biKZUNOZlS
# UnSypgvgv1ve+RfVyC8TXlf9PTnPC2pBeaeCrvZxPgQcxcqQixiQBFL/lzUtkakI
# rfBIYPp3U3++p2qdkk5DpZpIjuKIxXigqonoY7qnYEU/TWseQ12XsuLVnZ39swJv
# RaYjZSdDbw9bGYJiTgzKzmJUdpVEGYzSLr3VU7y/iwAFGVKfEbMBMYIENDCCBDAC
# AQEwgYMwbzELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEuMCwGA1UEAxMlRGlnaUNlcnQgQXNzdXJl
# ZCBJRCBDb2RlIFNpZ25pbmcgQ0EtMQIQD0Hibkz3FC41u2pRLZarJTAJBgUrDgMC
# GgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYK
# KwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG
# 9w0BCQQxFgQUE1tFbmbt0d/wLL6KnxB5mfBfjxMwDQYJKoZIhvcNAQEBBQAEggEA
# QfpjTLQwmENOm8ws8AsxdKM5mZ4/+rlYWVNsxSAlDY37181UQdbx016QtX7kQwm3
# QftdYm+qh9viuffIjO1fA6r6YKQYne2aeDW32hHSKM0yPeHs4ZO7cdaNwbL7z9fH
# Z6+7oReNwXnjL7nxaiXdUWJdSkYq1rdpkKV31Jv1CvIlaKPTAOcUMJj+uctVr8lA
# aNzcTPXWMWwVvoUI7XsMN5W1agxgo+tJElH9+0rTXBI6mgQt3AVfXdhoZqexD1eI
# jQ/VF37H/cOJyG63uboD/12BYvLOo4kVuE1U//aRIXoyA52pD9+MGkbJuVxV0JyE
# pe7NVAyup7DhbFy0UM7Q+qGCAgswggIHBgkqhkiG9w0BCQYxggH4MIIB9AIBATBy
# MF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEw
# MC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBDQSAtIEcy
# AhAOz/Q4yP6/NW4E2GqYGxpQMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0xMzEyMTIxNzE5NDNaMCMGCSqGSIb3
# DQEJBDEWBBQh9afXf1GCoJZ+DxsS6FplAgpqGDANBgkqhkiG9w0BAQEFAASCAQCE
# 77Cthg1SSxDnGr+sbNGhNKSSR3wLSiQB69odzF7CIk8yMqRWsHoHO67HdFlXcLSM
# 7hVditHcdsn8knGzbM2m1VHSXJVByyGpfu8ZMPo3oMy2HYUPc0ua178zsNHdZvY5
# MnWW8dQY9VGSzxbXONXWw6mQqH+m/qf1ee2kDlBK6hrJ3AkQ2wMcXZ4wtruFhNar
# G1PjFIRgDq/ueQS1zKjnFuE8B2ECUvASC1eNS0f65cSo1EsnjMB92FkovlUBUXXF
# fHH4VYDQM5qNYQllxVY0bBZjNQ8dpFqRm4CRphjHuvWRH3ffjZxa8zQcUFqj+8hH
# innCnQuGb/Q9uOQ/f9NQ
# SIG # End signature block
