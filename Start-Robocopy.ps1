# © 2016, Aleksey Ivanov

#region TODO

# Add fatal error mail notification
# Add external params (listing flag, etc...)
# Add exit code bit encoding

#endregion

#region Settings
#region General Settings
### Job display name (for email notification)
$sJobDisplayName = 'R&D Builds Copy (SPB to PRG)';
#$sJobDisplayName = 'Test - R&D Builds Copy (SPB to PRG)'

### Path to copy list, that contains source directory path, destination directory path and regexp filter for sub-paths
$sRuleListPath = '.\rules.csv';

### Full path to robocopy log directory
$sLogRootFolder = '.\logs';

### Base name of robocopy log files
$sLogBaseFileName = 'job.log';

### Full path to Robocopy executable file
$sRobocopyExePath = 'c:\windows\system32\robocopy.exe';

### Robocopy additional arguments
$aRobocopyArgs = [System.Array] (
								#	'/L',         # List only - don't copy, timestamp or delete any files.
								    '/E',         # Copy subdirectories, including Empty ones.
								    '/COPY:DAT',  # What to COPY for files (default is /COPY:DAT).
								#	'/Z',         # Copy files in restartable mode.
							        '/R:10',      # Number of Retries on failed copies: default 1 million.
							        '/W:30',      # Wait time between retries: default is 30 seconds.
							        '/V',         # Produce Verbose output, showing skipped files.
							        '/TS',        # Include source file Time Stamps in the output.
							        '/FP',        # Include Full Pathname of files in the output.
							        '/ETA',       # Show Estimated Time of Arrival of copied files.
							        '/NP'         # No Progress - don't display percentage copied.
								);
#endregion

#region Mail notification settings
### Mail sender address
$sMailFrom = 'robocopy@contoso.com';

### Mail recepient(s) address(es). 
# !!! Should be an array !!!
$aMailTo = [System.Array] ('admin@contoso.com');

### Mail relay server
$sMailServer = 'smtp.contoso.com';

### Mail relay server port
$iMailPort = 25;

# Mail HTML font family
#$sMailFontStyle = "font-family:consolas; courier new; courier"
#endregion
#endregion

########### AVOID CORRECTIONS BELOW THIS LINE ###########

. .\Get-CopyList.ps1

#region DEBUG LOG
function Write-Log {

	[CmdletBinding()]
	param(
		[ValidateNotNullOrEmpty()]
		[System.String] $Message,
		
		[ValidateNotNullOrEmpty()]
        [System.String] $FilePath = '.\logs\debug.log'
	)
	
    begin { }

	process {
	
        $sNoCarretReturnMessage = $Message.Replace( "`r", '' );
        if ( $sNoCarretReturnMessage -ne $null ) {
            $Message = $sNoCarretReturnMessage;
        }
		
        $aMessageLine = $Message.Split( "`n" );
        if ( $aMessageLine -eq $null ) {
            $aMessageLine = $Message;
        }
		
        foreach ( $sLine in $aMessageLine ) {
		
			if ( [System.String]::IsNullOrEmpty( $sLine ) ) {
				continue;
			}
	
			$oDateTime = Get-Date -ErrorAction SilentlyContinue;
			if ( $oDateTime -ne $null ) {
				
				$oDateTimeTimeUtc = $oDateTime.ToUniversalTime();
				if ( $oDateTimeTimeUtc -ne $null ) { # Got date and time in UTC successfully
					
					$sMessage = [System.String]::Format( "{0:dd.MM.yyyy}    {0,2:HH:mm:ss}.{1:000} UTC    {2}", $oDateTimeTimeUtc, $oDateTimeTimeUtc.Millisecond, $sLine );
					
				} else { # Unable to get date time in UTC
					
					$sMessage = [System.String]::Format( "{0:dd.MM.yyyy}    {0,2:HH:mm:ss}.{1:000}        {2}", $oDateTime, $oDateTime.Millisecond, $sLine );
				}
				
			} else { # Unable to get date and time
			
				$sMessage = [System.String]::Format( "??.??.????    ??:??:??.???        {0}", $sLine );
			}
			
			try {			
				Out-File -FilePath $FilePath -InputObject $sMessage -Encoding Default -Append -ErrorAction Stop;
				
			} catch { }
        }
    }
	
    end { }
}
#endregion

Write-Log -Message '--------------------------------------------------------------------------------';
Write-Log -Message 'Script started';

#region Checking and initializing settings
Write-Log -Message 'Setting checking started';

#region Checking copy rule list
if ( ( [System.String]::IsNullOrEmpty( $sRuleListPath ) ) -or 
     (  -not [System.IO.File]::Exists( $sRuleListPath ) ) ) {
    
	# Exiting if the copy file not specified or not exists     
	Write-Log -Message 'FATAL ERROR: Copy rules file not specified or not exists. Exiting.';
    return -1;
}
#endregion

#region Checking Robocopy Executable Path
# Checking if Robocopy executable specified in settings end exists
if ( ( [System.String]::IsNullOrEmpty( $sRobocopyExePath ) ) -or
     (  -not [System.IO.File]::Exists( $sRobocopyExePath ) ) ) {
    
    # Exiting with error if Robocopy executable not specified or not exists
	Write-Log -Message 'FATAL ERROR: Robocopy executable file not specified or not found. Exiting.';
    return -2;
}
#endregion

#region Checking Job Display Name
if ( [System.String]::IsNullOrEmpty( $sJobDisplayName ) ) {
	
	$sJobDisplayName = 'Unnamed job';
	Write-Log -Message 'WARNING: Job name not specified. Using default name.';
}
#endregion

#region Checking log root folder
if ( [System.String]::IsNullOrEmpty( $sLogRootFolder ) ) {
    
	Write-Log -Message 'WARNING: Log root folder not specified. Using temporary folder.';
	
    # Redirecting logs to temporary folder if custom folder not specified.
    $sLogRootFolder = [System.IO.Path]::GetTempPath();
    if ( -not [System.String]::IsNullOrEmpty( $sLogRootFolder ) ) {
        
        $sTmpLogRootFolder = [System.String]::Format( "{0}Robocopy", $sLogRootFolder );
        if ( -not [System.String]::IsNullOrEmpty( $sTmpLogRootFolder ) ) {
        
            # Adding subfolder for robocopy logs
            $sLogRootFolder = $sTmpLogRootFolder;
			
        } else {
			Write-Log -Message 'ERROR: Unable to generate log subfolder under temporary folder. Using temporary folder root path.';
		}
		
    } else {
		Write-Log -Message 'ERROR: Unable to get temporary folder path. Robocopy output logging disabled.';
	}
}
#endregion

#region Checking log file base file name
if ( [System.String]::IsNullOrEmpty( $sLogBaseFileName ) ) {
	
	# Using default log file base name
	$sLogBaseFileName = 'robocopy.log';
	Write-Log -Message 'WARNING: Log file base name not specified. Using default base name.';
}
#endregion

#region Checking Robocopy arguments
if ( $aRobocopyArgs -eq $null ) {
	
	# Nothing to do. Will be checked again before robocopy launch
	Write-Log -Message 'INFO: No additional robocopy paramaters specified. Robocopy will use default settings.';
}
#endregion

#region Checking Mail Sender
# Checking if Mail Sender was specified in settings
if ( [System.String]::IsNullOrEmpty( $sMailFrom ) ) { # Generating sender name using hostname if it wasn't specified in settings
    
	Write-Log -Message 'WARNING: No mail sender specified. Will use coputer name as part of the sender name.';
	
    $sComputerName = '';
    if ( -not [System.String]::IsNullOrEmpty( $env:COMPUTERNAME ) ) {
        
        # Getting hostname from environment variable
        $sComputerName = $env:COMPUTERNAME;

    } else { 
    
        # Using default hostname if hostname environment variable is empty
        $sComputerName = 'unknown_hostname';
		Write-Log -Message 'ERROR: Unable to get computer name. Using default value.';
    }
    
    # Generating sender name
    $sMailFrom = [System.String]::Format( "robocopy@{0}", $sComputerName )
    if ( [System.String]::IsNullOrEmpty( $sMailFrom ) ) {

        # Using default sender name if it was unable to generate
        $sMailFrom = 'robocopy@unknown_hostname';
		Write-Log -Message 'ERROR: Unable to generate sender name. Using default value.';
    }
}
#endregion

#region Mail Recipient(s)
# Checking if mail recepients list specified in settings
if ( $aMailTo -eq $null ) {
    
    # Initializing if it wasn't specified in settings
    $aMailTo = @();
	Write-Log -Message 'WARNING: Mail recepients not specified. Mail notification is disabled.';

} else {
    
    # Checking if the specified email addresses are correct and throw away incorrect ones 
    $aTmpMailTo = @();
    foreach ( $sMailTo in $aMailTo ) {

        if ( ( -not [System.String]::IsNullOrEmpty( $sMailTo ) ) -and
             ( [Regex]::IsMatch( $sMailTo , "(.*)\@(.*)" ) ) ) { # Accepted format is USER@DOMAIN
            
            # Addting correct addresses to temporary array
            $aTmpMailTo += $sMailTo;
			
        } else {
			Write-Log -Message "ERROR: An unacceptable mail recepient found: '$sMailTo'.";
		}
    }

    # Using only correct addresses
    $aMailTo = $aTmpMailTo;
}
#endregion

#region Mail Server
# Checking if SMTP relay specified in settings
if ( [System.String]::IsNullOrEmpty( $sMailServer ) ) {
	
	# Nothing to do. Will be checked again later, just before sending an email.	
	Write-Log -Message 'WARNING: Mail server not specified. Mail notification is disabled.';
}
#endregion

#region Mail Font Style
## Checking if HTML mail font style specified in settings
#if ( [System.String]::IsNullOrEmpty( $sMailFontStyle ) ) {
#
#    # Using default value if the parameter wasn't specified in settings
#    $sMailFontStyle = "font-family: consolas; courier new; courier"
#}
#endregion

Write-Log -Message 'Settings checking ended';
#endregion

#region Initializing log infrastructure
Write-Log -Message 'Log infrastructure initialization started';

#region Adding current date and time to root log folder path
if ( -not [System.String]::IsNullOrEmpty( $sLogRootFolder ) ) {

	# If suddenly we're unable to get current date this part of log root folder path will be skipped
	$oStartDateTime = Get-Date;
	if ( $oStartDateTime -ne $null ) {
		
		#region Adding start date to path
		$sTmpLogRootFolder = [System.String]::Format( "{0}\{1:yyyy}-{1:MM}-{1:dd}\{1:HH}-{1:mm}-{1:ss}", $sLogRootFolder, $oStartDateTime );
		if ( -not [System.String]::IsNullOrEmpty( $sTmpLogRootFolder ) ) {
		
			$sLogRootFolder = $sTmpLogRootFolder;
		}
		<#
		$sStartDate = [System.String]::Format( "{0:yyyy}-{0:MM}-{0:dd}", $oStartDateTime )		
		if ( -not [System.String]::IsNullOrEmpty( $sStartDate ) ) {
			
			$sTmpLogRootFolder = [System.String]::Format( "{0}\{1}", $sLogRootFolder, $sStartDate )
			if ( -not [System.String]::IsNullOrEmpty( $sTmpLogRootFolder ) ) {
			
				$sLogRootFolder = $sTmpLogRootFolder
				
				#region Adding start time to path
				$sStartTime = [System.String]::Format( "{0:HH}-{0:mm}-{0:ss}", $oStartDateTime )				
				if ( -not [System.String]::IsNullOrEmpty( $sStartTime ) ) {
			        
			        $sTmpLogRootFolder = [System.String]::Format( "{0}\{1}", $sLogRootFolder, $sStartTime )
					if ( -not [System.String]::IsNullOrEmpty( $sTmpLogRootFolder ) ) {
					
						$sLogRootFolder = $sTmpLogRootFolder
					}
			    }
				#endregion
			}
		}
		#>
		#endregion		
	
	} else {
		Write-Log -Message 'ERROR: Unable to get current DateTime. Will use log folder root path without current date and time.';
	}
}
#endregion

#region Checking if the root log folder path is set and exists
if ( -not [System.String]::IsNullOrEmpty( $sLogRootFolder ) ) {

	if ( -not [System.IO.Directory]::Exists( $sLogRootFolder ) ) {
	
		# Creating path to log root folder if not exists
		$oLogRootFolder = New-Item -Path $sLogRootFolder -ItemType Directory -Force;
		
	    if ( $oLogRootFolder -ne $null ) {
	        $sLogRootFolder = $oLogRootFolder.FullName;
			
	    } else {
			Write-Log -Message 'ERROR: Unable to create log root folder. Will use temporary folder.';
			
			# Redirecting logs to temporary folder if custom folder can't be created.
		    $sLogRootFolder = [System.IO.Path]::GetTempPath();
		    if ( -not [System.String]::IsNullOrEmpty( $sLogRootFolder ) ) {

		        $sTmpLogRootFolder = [System.String]::Format( "{0}Robocopy", $sLogRootFolder );
				if ( -not [System.String]::IsNullOrEmpty( $sTmpLogRootFolder ) ) {
		        
		            # Adding subfolder for robocopy logs
		            $sLogRootFolder = $sTmpLogRootFolder;
					
		        } else {
					Write-Log -Message 'ERROR: Unable to generate log subfolder under temporary folder. Using temporary folder root path.';
				}
				
		    } else {
				Write-Log -Message 'ERROR: Unable to get temporary folder path. Robocopy output logging is disabled.';
			}
		}	
	}
}
#endregion

#region Generating log file base path
$sLogFilePath = $null;
if ( -not [System.String]::IsNullOrEmpty( $sLogRootFolder ) ) {
	
	if ( -not [System.String]::IsNullOrEmpty( $sLogBaseFileName ) ) {
    
	    $sTmpLogFilePath = [System.String]::Format( "{0}\{1}", $sLogRootFolder, $sLogBaseFileName );
		if ( -not [System.String]::IsNullOrEmpty( $sTmpLogFilePath ) ) {
		
			$sLogFilePath = $sTmpLogFilePath;
		}
		
	} else {
		Write-Log -Message 'ERROR: Log file base name is NULL. Check script. Looks like it was overwritted because of script error. Robocopy output logging is disabled.';
	}	
}

if ( [System.String]::IsNullOrEmpty( $sLogFilePath ) ) {
	Write-Log -Message 'ERROR: Unable to generate log file base full path. Robocopy output logging is disabled.';
}

#endregion
Write-Log -Message 'Log infrastructure initialization ended';
#endregion

#region Creating copy rules list
Write-Log -Message 'Copy rules list generation started';

#region Retreiving copy rules
Write-Log -Message 'Get-CopyList cmdlet started';

$aCopyRule = [System.Array] ( Get-CopyList -Path $sRuleListPath -ErrorVariable oError )
if ( $oError.Count -gt 0 ) {	
	Write-Log -Message 'FATAL ERROR: Unable to load copy rules from file. Exiting.';
	return -5;
}
if ( ( $aCopyRule -eq $null ) -or ( $aCopyRule.Count -le 0 ) ) {	
	Write-Log -Message 'WARNING: No copy rules discovered that meet specified copy rules list. Exiting.';
	return 0;
}

<#
$aCopyRule = [System.Array] ( Get-CopyList -Path $sRuleListPath -ErrorAction SilentlyContinue )
if ( ( $aCopyRule -eq $null ) -or ( $aCopyRule.Count -le 0 ) ) {

	Write-Log -Message 'FATAL ERROR: Unable to load copy rules from file. Exiting.'
	
	# Exiting with an error code if copy list is empty
    return -5
}
#>

Write-Log -Message 'Get-CopyList cmdlet ended';
Write-Log -Message "Discovered $($aCopyRule.Count) rule(s)";
#endregion

#region Adding fields to copy rules list
Write-Log -Message 'Enhanced fileds addition started';

# Resultant set of copy rules with additional fields
$aEnhancedCopyRule = @();

# Adding fields to copy rules list
for ( [System.Int32] $iRuleIndex = 0; $iRuleIndex -lt $aCopyRule.Count; $iRuleIndex++ ) { # Adding fields to copy rules loop

	$oCopyRule = New-Object PSObject `
					-Property @{
						         Source       = $aCopyRule[ $iRuleIndex ].Source
						         Destination  = $aCopyRule[ $iRuleIndex ].Destination
								 ExitCode	  = $null
								 LogFilePath  = $null } | select Source, Destination, ExitCode, LogFilePath;
	
	if ( $oCopyRule -eq $null ) {			
		# Breaking the loop. Unable to add extended fields to one of the rules
		$iRuleIndex = $aCopyRule.Count;
		continue;
	} 
	
	$aEnhancedCopyRule += $oCopyRule;
	
} # Adding fields to copy rules loop

# Checking results
if ( $aCopyRule.Count -ne $aEnhancedCopyRule.Count ) { # Unable to add extended fields to one of the rules
	
	Write-Log -Message 'FATAL ERROR: Unable to add extended fields to a copy rule. Exiting.';
	return -1;
}

# Atlering copy rules array if all fields was successfully added to all items
$aCopyRule = $aEnhancedCopyRule;

Write-Log -Message 'Enhanced fields addition ended';
#endregion

Write-Log -Message 'Copy rules list generation ended';
#endregion

#region Running Robocopy for resultant set of copy rules
Write-Log -Message 'Robocopy jobs execution loop started';

# Process not created
$aProcessNotCreated = @();

for ( [System.Int32] $iRuleIndex = 0; $iRuleIndex -lt $aCopyRule.Count; $iRuleIndex++ ) { # Start robocopy for each copy rule loop
    
	#region Adding unique id to log file name
	Write-Log -Message 'Log file name generation started';
	
	$sJobLogFilePath = $null;

    #region Adding unique number to log file name
	if ( -not [System.String]::IsNullOrEmpty( $sLogFilePath ) ) {

        $sLogFileDirectory = [System.IO.Path]::GetDirectoryName( $sLogFilePath );
        $sLogFileExtension = [System.IO.Path]::GetExtension( $sLogFilePath );
        $sLogFileName      = [System.IO.Path]::GetFileNameWithoutExtension( $sLogFilePath );

        if ( ( -not [System.String]::IsNullOrEmpty( $sLogFileDirectory ) ) -and 
             ( -not [System.String]::IsNullOrEmpty( $sLogFileExtension ) ) -and
             ( -not [System.String]::IsNullOrEmpty( $sLogFileName ) ) ) {
        
			# Using unique number in log file name
            $sTmpLogFilePath = [System.String]::Format( 
	                "{0}\{1}.{2}{3}",
	                $sLogFileDirectory,
	                $sLogFileName,
	                ($iRuleIndex + 1).ToString(),
	                $sLogFileExtension
	            );
			
            if ( -not [System.String]::IsNullOrEmpty( $sTmpLogFilePath ) ) {
                $sJobLogFilePath = $sTmpLogFilePath;
            }
        } 
    }
	
	if ( [System.String]::IsNullOrEmpty( $sJobLogFilePath ) ) {
		Write-Log -Message 'ERROR: Unable to add unique number to log file for current job. Robocopy output logging for currnet job is disabled.';
	}
    #endregion
	
	#region Adding log file path to copy rule
	if ( -not [System.String]::IsNullOrEmpty( $sJobLogFilePath ) ) {
		$aCopyRule[ $iRuleIndex ].LogFilePath = $sJobLogFilePath;
	}
	#endregion
	
	Write-Log -Message 'Log file name generation ended';
	#endregion
	
    #region Generating Robocopy startup params array
	$aRobocopyStartupArgs = [System.Array] (
	        "`"$($aCopyRule[ $iRuleIndex ].Source)`"",      # Source directory
	        "`"$($aCopyRule[ $iRuleIndex ].Destination)`""  # Destination directory
        );
    if ( ( $aRobocopyStartupArgs       -eq $null ) -or
         ( $aRobocopyStartupArgs.Count -ne 2 ) ) { 
		 
		# No or to low arguments specified
		Write-Log -Message 'FATAL ERROR: Unable to Robocopy startup arguments using source and destination directories. Exiting.';
		return -6;
    }
	
	# Adding parameters from settings if specified
	if ( ( $aRobocopyArgs -ne $null ) -and ( $aRobocopyArgs.Count -gt 0 ) ) {		
		$aRobocopyStartupArgs += $aRobocopyArgs;
	}
    #endregion
    
    #region Starting Robocopy
	Write-Log -Message "Robocopy is starting for job #$($iRuleIndex + 1) of $($aCopyRule.Count) (source path: $($aCopyRule[ $iRuleIndex ].Source))";
	
	if ( -not [System.String]::IsNullOrEmpty( $sJobLogFilePath ) ) {
    	
		#region Redirecting robocopy's output to the specified log file
		if ( ( $Host -ne $null ) -and ( $Host.Version -ne $null ) -and ( $Host.Version.Major -gt 2 ) ) {
			 
			# Using new features of Start-Process cmdlet to hide robocopy's window
			$oProcess = Start-Process `
				-FilePath $sRobocopyExePath `
				-ArgumentList $aRobocopyStartupArgs `
				-RedirectStandardOutput $sJobLogFilePath `
				-WindowStyle Hidden `
				-PassThru `
				-Wait `
				-ErrorAction SilentlyContinue;
			
		} else {
		
			# Backward compapatibility with PowerShell 2.0
			$oProcess = Start-Process `
				-FilePath $sRobocopyExePath `
				-ArgumentList $aRobocopyStartupArgs `
				-RedirectStandardOutput $sJobLogFilePath `
				-PassThru `
				-Wait `
				-ErrorAction SilentlyContinue;
		}
		#endregion
				
	} else {	
	
		#region No robocopy's output redirection
		if ( ( $Host -ne $null ) -and ( $Host.Version -ne $null ) -and ( $Host.Version.Major -gt 2 ) ) {
			
			# Using new features of Start-Process cmdlet to hide robocopy's window
			$oProcess = Start-Process `
				-FilePath $sRobocopyExePath `
				-ArgumentList $aRobocopyStartupArgs `
				-WindowStyle Hidden `
				-PassThru `
				-Wait `
				-ErrorAction SilentlyContinue;
			
		} else {
			
			# Backward compapatibility with PowerShell 2.0
			$oProcess = Start-Process `
				-FilePath $sRobocopyExePath `
				-ArgumentList $aRobocopyStartupArgs `
				-PassThru `
				-Wait `
				-ErrorAction SilentlyContinue;
		}
		#endregion
	}
	
	Write-Log -Message "Robocopy is ended for job #$($iRuleIndex + 1)";
	#endregion
		
	#region Analyzing output
    Write-Log -Message 'Analyzing output started';
	
	if ( $oProcess -eq $null ) { # Process was not created. Non-fatal error
		Write-Log -Message 'ERROR: Unable to create process object for current Robocopy task. Exit code analysis for current skipped.';
		$aProcessNotCreated += $aCopyRule[ $iRuleIndex ];
        continue;
    }

    #region Saving exit code
	if ( $oProcess.ExitCode -ne $null ) {
	
		# Saving exit code to rule object
		$aCopyRule[ $iRuleIndex ].ExitCode = $oProcess.ExitCode;
		
		# Adding exit code to log file (if the file is specified)
		if ( -not [System.String]::IsNullOrEmpty( $sJobLogFilePath ) ) {
		
			$sExitCodeMessage = [System.String]::Format( "`n`n   Robocopy has exited with code {0}.", $oProcess.ExitCode );
			if ( -not [System.String]::IsNullOrEmpty( $sExitCodeMessage ) ) {
	        	Out-File -InputObject $sExitCodeMessage -FilePath $sJobLogFilePath -Append -Encoding Default -ErrorAction SilentlyContinue;
			} else {
				Write-Log -Message 'WARNING: Unable to add exit code to current Robocopy task output log.';
			}
	    }
		
	} else {
		Write-Log -Message 'WARNING: Exit code for current Robocopy taks object is null. Exit code analysis for current task skipped.';
	}
	#endregion
	
	Write-Log -Message 'Analyzing output ended';
    #endregion
	
} # Start robocopy for each copy rule loop

Write-Log -Message 'Robocopy jobs execution loop ended';
#endregion

#region Analyzing copy results
Write-Log -Message 'Analyzing copy jobs results loop started';

#region Robocopy return codes definition
# Basic return codes
$iExitCode_Success_NoNewItems		= 0;	# 00000 No errors occurred, and no copying was done. The source and destination directory trees are completely synchronized. 
$iExitCode_Success_NewItemsCopied	= 1; 	# 00001 One or more files were copied successfully (that is, new files have arrived).
$iExitCode_Warning_ExtraItems		= 2;	# 00010 Some Extra files or directories were detected. No files were copied. Examine the output log for details. 
$iExitCode_Warning_Mismatch			= 4;	# 00100 Some Mismatched files or directories were detected. Examine the output log. Housekeeping might be required.
$iExitCode_Error_ItemCopy 			= 8;	# 01000 Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded). Check these errors further.
$iExitCode_Error_AllItemsCopy 		= 16;	# 10000 Serious error. Robocopy did not copy any files. Either a usage error or an error due to insufficient access privileges on the source or destination directories.

# Possible return codes combinations
# 3 = 00011 (2+1) Some files were copied. Additional files were present. No failure was encountered.
# 5 = 00101 (4+1) Some files were copied. Some files were mismatched. No failure was encountered.
# 6 = 00110 (4+2) Additional files and mismatched files exist. No files were copied and no failures were encountered. This means that the files already exist in the destination directory.
# 7 = 00111 (4+1+2) Files were copied, a file mismatch was present, and additional files were present.
#endregion

# Errors, warnings, success and unknown jobs' log path
$aJobSuccessLog = @();
$aJobWarningLog = @();
$aJobErrorLog   = @();
$aJobUnknownLog = @();

# Script return code
$iScriptReturnCode = 0;

# Analyzing copy results loop
for ( [System.Int32] $iRuleIndex = 0; $iRuleIndex -lt $aCopyRule.Count; $iRuleIndex++ ) { 
	
	#region Saving log file path to rule object
	if ( -not [System.String]::IsNullOrEmpty( $aCopyRule[ $iRuleIndex ].LogFilePath ) ) {
		
		#region No exit code
		if ( $aCopyRule[ $iRuleIndex ].ExitCode -eq $null ) {
			$aJobUnknownLog += $aCopyRule[ $iRuleIndex ].LogFilePath;
			continue;
		}
		#endregion
		
		#region Success exit codes
		if ( (   $aCopyRule[ $iRuleIndex ].ExitCode -eq   $iExitCode_Success_NoNewItems ) -or 				   # 00000 No errors occurred, and no copying was done. The source and destination directory trees are completely synchronized.
		     ( ( $aCopyRule[ $iRuleIndex ].ExitCode -band $iExitCode_Success_NewItemsCopied ) -ne 0 ) -or 	   # 00001 One or more files were copied successfully (that is, new files have arrived).
		     ( ( $aCopyRule[ $iRuleIndex ].ExitCode -band $iExitCode_Warning_ExtraItems ) -ne 0 ) ) {   # 00010 Some Extra files or directories were detected. No files were copied. Examine the output log for details. 

			$aJobSuccessLog += $aCopyRule[ $iRuleIndex ].LogFilePath;
		}
		#endregion
		
		#region Warning exit codes
		if ( ( $aCopyRule[ $iRuleIndex ].ExitCode -band $iExitCode_Warning_Mismatch ) -ne 0 ) {                # 00100 Some Mismatched files or directories were detected. Examine the output log. Housekeeping might be required.
			$aJobWarningLog += $aCopyRule[ $iRuleIndex ].LogFilePath;
		} 
		#endregion
		
		#region Error exit codes
		if ( ( ( $aCopyRule[ $iRuleIndex ].ExitCode -band $iExitCode_Error_ItemCopy     ) -ne 0 ) -or 		   # 01000 Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded). Check these errors further.
		     ( ( $aCopyRule[ $iRuleIndex ].ExitCode -band $iExitCode_Error_AllItemsCopy ) -ne 0 ) ){           # 10000 Serious error. Robocopy did not copy any files. Either a usage error or an error due to insufficient access privileges on the source or destination directories.
		
			$aJobErrorLog += $aCopyRule[ $iRuleIndex ].LogFilePath;
		}
		#endregion
	}
	#endregion
		
	# Setting script return code to highest possible value (lower - better)
	if ( $iScriptReturnCode -lt $aCopyRule[ $iRuleIndex ].ExitCode ) {
		$iScriptReturnCode = $aCopyRule[ $iRuleIndex ].ExitCode;
	}
		
} # Analyzing copy results loop

Write-Log -Message 'Analyzing copy jobs results loop ended';
#endregion

#region Generating notification email
Write-Log -Message 'Generating notification email started';

#region Generating mail body
#region Initializing mail body with summary
try {
	$sMailBody = [System.String]::Format( 
			"Directory copy statistics for job '$sJobDisplayName'`n`n" +
			"Total directories discovered: {0}`n`n" +
			"Successfully processed: {1}`n" +
			"Warning(s) issued: {2}`n" +
			"Error(s) occured: {3}`n" +
			"Unknown status(-es): {4}`n",
			$aCopyRule.Count,
			$aJobSuccessLog.Count,
			$aJobWarningLog.Count,
			$aJobErrorLog.Count,
			$aJobUnknownLog.Count
		);
	
	if ( [System.String]::IsNullOrEmpty( $sMailBody ) ) {
		throw ( New-Object System.Exception( "A null-value was returned from System.String.Format()." ) );
	}
	
} catch {
	Write-Log -Message 'ERROR: Unable to generate summary for email notification body';
}
#endregion

#region Generating time information message
try {
	if ( $oStartDateTime -eq $null ) { 
		Write-Log -Message 'ERROR: Unable to get script start date and time';
		throw ( New-Object System.Exception( "The object representing start time of the script is null." ) );
	} 

	$oFinishDateTime = Get-Date;
	if ( $oFinishDateTime -eq $null ) {
		Write-Log -Message 'ERROR: Unable to get script finish date and time';
		throw ( New-Object System.Exception( "A null-value was returned from Get-Date cmdlet." ) );
	} 
		
	$oRunTime = $oFinishDateTime - $oStartDateTime;
	if ( $oRunTime -eq $null ) {
		Write-Log -Message 'ERROR: Unable to calculate script execution time';
		throw ( New-Object System.Exception( "A null-value was returned while attempting to calculate script execution time." ) );
	} 	
	
	$sTimeInfo = [System.String]::Format( 
			"Start time: {0}, {1}`n" +
			"Finish time: {2}, {3}`n" +
			"Execution time: {4} day(s) {5} hour(s) {6} minute(s) {7} second(s)`n",
			$oStartDateTime.ToShortDateString(),
			$oStartDateTime.ToLongTimeString(),
			$oFinishDateTime.ToShortDateString(),
			$oFinishDateTime.ToLongTimeString(),
			$oRunTime.Days,
			$oRunTime.Hours,
			$oRunTime.Minutes,
			$oRunTime.Seconds
		);
		
	if ( [System.String]::IsNullOrEmpty( $sTimeInfo ) ) {
		throw ( New-Object System.Exception( "A null-value was returned from System.String.Format() while attempting to generate time info block." ) );
	} 
	
	$sTmpMailBody = [System.String]::Format(
			"{0}`n" + 																				# Previous part of the mail body
			"--------------------------------------------------------------------------------`n" +  # Block separator
			"`n{1}`n",																				# Current part of the mail body
			$sMailBody, 
			$sTimeInfo
		);
		
	if ( [System.String]::IsNullOrEmpty( $sTmpMailBody ) ) {	
		throw ( New-Object System.Exception( "A null-value was returned from System.String.Format(). while attempting to add time info block to email notification body." ) );
	}
	
	$sMailBody = $sTmpMailBody;

} catch {
	Write-Log -Message 'ERROR: Unable to generate time information message. Will skip this block.';
}
#endregion

#region Writing skipped copy rules
if ( ( $aCopyRuleSkipped -ne $null ) -and ( $aCopyRuleSkipped.Count -gt 0 ) ) {

	$sInfo = $null;
	for ( [System.Int32] $iRuleIndex = 0; $iRuleIndex -lt $aCopyRuleSkipped.Count; $iRuleIndex++ ){ # Rules listing loop
				
		try {
			$sTmpInfo = [System.String]::Format( 
					"{0}`n`n" +
					"`tRule #{1}`n" +
					"`tSource: {2}`n" +
					"`tDestination: {3}",
					$sInfo, 
					$iRuleIndex + 1,
					$aCopyRuleSkipped[ $iRuleIndex ].Source, 
					$aCopyRuleSkipped[ $iRuleIndex ].Destination
				);
				
			if ( [System.String]::IsNullOrEmpty( $sTmpInfo ) ) {
				throw ( New-Object System.Exception( "A null-value was returned from System.String.Format()." ) );
			} 
			
			$sInfo = $sTmpInfo;
						
		} catch {
			Write-Log 'ERROR: Unable to generate skipped rule message. Will skip this block.';
		}
		
	} # Rules listing loop
	
	try {
		if ( [System.String]::IsNullOrEmpty( $sInfo ) ) {
			throw ( New-Object System.Exception( "A null-value was returned from rule listing loop." ) );
		}
		
		$sTmpMailBody = [System.String]::Format( 
			"{0}" + 																				 # Previous part of the mail body
			"--------------------------------------------------------------------------------`n`n" + # Block separator
			"The following backup rules was skipped because of source directory is INACCESSIBLE:"  + # Block header
			"{1}`n",																				 # Current part of the mail body
			$sMailBody, 
			$sInfo
		);
		if ( [System.String]::IsNullOrEmpty( $sTmpMailBody ) ) {
			throw ( New-Object System.Exception( "A null-value was returned from System.String.Format() while attempting to add skipped rule(s) details to email notification body." ) );
		}
			
		$sMailBody = $sTmpMailBody;
		
	} catch {
		Write-Log -Message 'ERROR: Unable to add skipped rule(s) details to email notification body.';
	}
}
#endregion

#region Adding error logs to mail body
if ( ( $aJobErrorLog -ne $null ) -and ( $aJobErrorLog.Count -gt 0 ) ) {
	
	$sInfo = $null;
	for ( [System.Int32] $iLogIndex = 0; $iLogIndex -lt $aJobErrorLog.Count; $iLogIndex++ ) { # Log files listing loop
		
		try {
			$sTmpInfo = [System.String]::Format( "{0}`t{1}`n", $sInfo, $aJobErrorLog[ $iLogIndex ] );
			
			if ( [System.String]::IsNullOrEmpty( $sTmpInfo ) ) {
				throw ( New-Object System.Exception( "A null-value was returned from System.String.Format()." ) );
			}
			$sInfo = $sTmpInfo;
			
		} catch {
			Write-Log -Message 'ERROR: Unable to add information about job with error(s) to email notification body.';
		}
		
	} # Log files listing loop
	
	try {	
		if ( [System.String]::IsNullOrEmpty( $sInfo ) ) {
			throw ( New-Object System.Exception( "A null-value was returned from rule listing loop." ) );
		}
		
		$sTmpMailBody = [System.String]::Format( 
			"{0}`n" + 																				 # Previous part of the mail body
			"--------------------------------------------------------------------------------`n`n" + # Block separator
			"Local path to log file(s) for directory copy job(s) with ERROR exit code(s):`n`n" +     # Block header
			"{1}`n",																				 # Current part of the mail body
			$sMailBody, 
			$sInfo
		);
		if ( [System.String]::IsNullOrEmpty( $sTmpMailBody ) ) {
			throw ( New-Object System.Exception( "A null-value was returned from System.String.Format() while attempting to add rule(s) with error details to email notification body." ) );
		} 
		
		$sMailBody = $sTmpMailBody;
		
	} catch {
		Write-Log -Message 'ERROR: Unable to add failed rule(s) details to email notification body';
	}
}
#endregion

#region Adding warning logs to mail body
if ( ( $aJobWarningLog -ne $null ) -and ( $aJobWarningLog.Count -gt 0 ) ) {
	
	$sInfo = $null;
	for ( [System.Int32] $iLogIndex = 0; $iLogIndex -lt $aJobWarningLog.Count; $iLogIndex++ ) { # Log files listing loop
		
		try {
			$sTmpInfo = [System.String]::Format( "{0}`t{1}`n", $sInfo, $aJobWarningLog[ $iLogIndex ] );
			
			if ( [System.String]::IsNullOrEmpty( $sTmpInfo ) ) {
				throw ( New-Object System.Exception( "A null-value was returned from System.String.Fromat()." ) );
			}
			$sInfo = $sTmpInfo;
			
		} catch {
			Write-Log -Message 'ERROR: Unable to add information about job with warning(s) to email notification body.';
		}
		
	} # Log files listing loop
	
	try {		
		if ( [System.String]::IsNullOrEmpty( $sInfo ) ) {
			throw ( New-Object System.Exception( "A null-value was returned from rule listing loop." ) );
		}
		
		$sTmpMailBody = [System.String]::Format( 
			"{0}`n" + 																				 # Previous part of the mail body
			"--------------------------------------------------------------------------------`n`n" + # Block separator
			"Local path to log file(s) for directory copy job(s) with WARNING exit code(s):`n`n"  +  # Block header
			"{1}`n",																				 # Current part of the mail body
			$sMailBody, 
			$sInfo
		);
		if ( [System.String]::IsNullOrEmpty( $sTmpMailBody ) ) {
			throw ( New-Object System.Exception( "A null-value was returned from System.String.Format() while attempting to add rule(s) with warning details to email notification body." ) )
		}
		$sMailBody = $sTmpMailBody;
	
	} catch {
		Write-Log -Message 'ERROR: Unable to add information about job(s) with warning(s) to email notification body.';
	}
}
#endregion

#region Adding unknown logs to mail body
if ( $aJobUnknownLog.Count -gt 0 ) {
	
	$sInfo = $null;
	for ( [System.Int32] $iLogIndex = 0; $iLogIndex -lt $aJobUnknownLog.Count; $iLogIndex++ ) { # Log files listing loop
		
		try{
			$sTmpInfo = [System.String]::Format( "{0}`t{1}", $sInfo, $aJobUnknownLog[ $iLogIndex ] );
			
			if ( [System.String]::IsNullOrEmpty( $sTmpInfo ) ) {			
				throw ( New-Object System.Exception( "A null-value was returned from System.String.Fromat()." ) );
			}
			$sInfo = $sTmpInfo;
		
		} catch {
			Write-Log -Message 'ERROR: Unable to add information about job with unknow status to email notification body.';
		}
		
	}# Log files listing loop
	
	try {
		if ( [System.String]::IsNullOrEmpty( $sInfo ) ) {
			throw ( New-Object System.Exception( "A null-value was returned from rule listing loop." ) );
		}
		
		$sTmpMailBody = [System.String]::Format( 
			"{0}`n" + 																				 # Previous part of the mail body
			"--------------------------------------------------------------------------------`n`n" + # Block separator
			"Local path to log file(s) for directory copy job(s) with UNKNOWN exit code(s):`n`n"  +  # Block header
			"{1}`n",																				 # Current part of the mail body
			$sMailBody, 
			$sInfo
		);
		if ( [System.String]::IsNullOrEmpty( $sTmpMailBody ) ) {
			throw ( New-Object System.Exception( "A null-value was returned from System.String.Format() while attempting to add rule(s) with unknown exit code details to email notification body." ) );
		} 
		$sMailBody = $sTmpMailBody;
			
	} catch {
		Write-Log -Message 'ERROR: Unable to add information about job(s) with unknow status to email notification body.';
	}
}
#endregion

#region Checking mail body
# Using default email body, if we're unable to generate custom one
if ( [System.String]::IsNullOrEmpty( $sMailBody ) ) {
	$sMailBody = 'ERROR GENERATING EMAIL NOTIFICATION MESSAGE.';
	Write-Log -Message 'ERROR: Unable to generate email notification body.';
}
#endregion
#endregion

#region Generating subject
#region Generating status string
$sStatus = 'Unknown';
if ( ( $aJobErrorLog.Count     -gt 0 ) -or
     ( $aCopyRuleSkipped.Count -gt 0 ) ) {

	$sStatus = 'Error';
	
} elseif ( ( $aJobWarningLog.Count -gt 0 ) -or 
           ( $aJobUnknownLog.Count -gt 0 ) ) {

	$sStatus = 'Warning';

} elseif ( $aJobSuccessLog.Count -gt 0 ) {
	
	$sStatus = 'Success';
}
#endregion

#region Formating Subject
$sMailSubject = $null;
try {
	$sMailSubject = [System.String]::Format( "[{0}] {1}", $sStatus, $sJobDisplayName )
	if ( [System.String]::IsNullOrEmpty( $sMailSubject ) ) { # Using default email subject, if we're unable to generate custom one
		throw ( New-Object System.Exception( "A null-value was returned from System.String.Format()." ) );
	}
	
} catch {

	$sMailSubject = 'Robocopy job notification';
	Write-Log -Message 'ERROR: Unable to generate mail notification subject.';
}
#endregion
#endregion

#region Sending mail
if ( ( $aMailTo -ne $null ) -and ( $aMailTo.Count -gt 0 ) -and
	 ( -not [System.String]::IsNullOrEmpty( $sMailFrom    ) ) -and 
	 ( -not [System.String]::IsNullOrEmpty( $sMailServer  ) ) -and 
	 ( -not [System.String]::IsNullOrEmpty( $sMailSubject ) ) -and
	 ( -not [System.String]::IsNullOrEmpty( $sMailBody    ) ) ) {
	 
	#region Generating anonymous credentials
	#TODO: add error handling
	$oMailUserPass = ConvertTo-SecureString 'anonymous' -AsPlainText -Force;
	$oSmtpCredentials = New-Object System.Management.Automation.PSCredential( 'anonymous' , $oMailUserPass );
	#endregion 

	Send-MailMessage `
	        -To $aMailTo `
	        -From $sMailFrom `
	        -SmtpServer $sMailServer `
	        -Port $iMailPort `
	        -Subject $sMailSubject `
	        -Body $sMailBody `
	        -Credential $oSmtpCredentials `
			-ErrorVariable oError;

	if ( ( $oError -ne $null ) -and ( $oError.Count -gt 0 ) ) {
		Write-Log -Message "ERROR: failed to send an email notification. $($oError[0].Exception.Message)";
	}

} else {
	Write-Log -Message 'ERROR: send an email notification because required field(s) is (are) not set.';
}
#endregion

Write-Log -Message 'Generating notification email ended';
#endregion

Write-Log -Message 'Script ended';

return $iScriptReturnCode;