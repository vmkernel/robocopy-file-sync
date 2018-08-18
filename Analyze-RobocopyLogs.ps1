# Initialy created by Aleksey Ivanov, 2016.

. .\ConvertTo-Bytes.ps1

<#
.SYNOPSIS
	Gets statistics from robocopy log files
	
.DESCRIPTION
	The Get-RobocopyLogStatistics cmdlet analyses robocopy's log files and retreives statistics for files, directories and copied bytes, such as Total, Copied, Skipped, Mismatch, Extras and Failed
	The cmdlet RECURSIVELY lists all log files located in a specified directory.
	
	It's possible to use Filter parameter (that accepts wildcards) in order to narrow search.
	
	The cmdlet accepts source directory paths from the pipeline.
	
.EXAMPLE
	Get-RobocopyLogStatistics -LogDirectoryPath d:\logs\01-07-2016
	This command recursively analyses ALL files located in the specified directory assuming that all of them are robocopy log files.
	
	Get-RobocopyLogStatistics -LogDirectoryPath d:\logs\01-07-2016 -Filter *.log
	This command recursively analyses files that matches '*.log' filter and located in the specified directory assuming that all of them are robocopy log files.
	
.INPUTS
	[System.String] LodDirectoryPath - Full path to source directory.
	[System.String] Filter           - File name filter.
	
.OUTPUTS
	[System.Object] on success.
  	NULL            on failure.
	
.NOTE
	The cmdlet relies on a custom cmdlet 'ConvertTo-Bytes'.
	
	The robocopy log file should contain at least the following section at the end of the file:
	
	               Total    Copied   Skipped  Mismatch    FAILED    Extras
	    Dirs :         1         0         0         0         0         0
	   Files :         2         0         2         0         0         0
	   Bytes :   3.113 g         0   3.113 g         0         0         0
	   Times :   0:00:00   0:00:00                       0:00:00   0:00:00
	   Ended : Friday, July 1, 2016 2:03:20 PM
#>
function Get-RobocopyLogStatistics {

	[CmdletBinding( SupportsShouldProcess = $true, 
                    ConfirmImpact         = 'Low' )]
	
	[OutputType( [System.Object] )]		
	
	param (
		# Full path to a directory that contains log files
		[Parameter( 
			Mandatory = $true, 
			ValueFromPipeline = $true, 
			ValueFromPipelineByPropertyName = $true 
		)]
		[ValidateNotNullOrEmpty()]
		[System.String] 
		$LogDirectoryPath,
		
		# File name filter string
		[Parameter( Mandatory = $false )]
		[System.String]
		$Filter
	)
	
	begin { 
		
		# Cmdlet stop flag
		$bStopProcessing = $false;
		
		#region RegExp patterns
		# Summary block header
		$sPatternHeader = "^\s*total\s*copied\s*skipped\s*mismatch\s*failed\s*extras$";
		
		# Directories summary row prefix
		$sPatternDirs   = "^\s*dirs\s:";
		
		# Files summary row prefix
		$sPatternFiles  = "^\s*files\s:";
		
		# Bytes summary row prefix
		$sPatternBytes  = "^\s*bytes\s:";
		
		# Times summary row prefix
		$sPatternTimes  = "^\s*times\s:";
		
		# Summary block footer
		$sPatternEnded  = "^\s*ended\s:";
		
		# Number/size in bytes detection RegExp  
		$sPatternNumber = "(((\d+\.{0,1}\d+)|(\d+))\s(k|m|g)|\d+)";
		#endregion
		
		#region Checking if RegExp pattern initialized successfully
		if ( [System.String]::IsNullOrEmpty( $sPatternHeader ) -or 
			 [System.String]::IsNullOrEmpty( $sPatternDirs   ) -or 
			 [System.String]::IsNullOrEmpty( $sPatternFiles  ) -or 
			 [System.String]::IsNullOrEmpty( $sPatternBytes  ) -or 
			 [System.String]::IsNullOrEmpty( $sPatternTimes  ) -or 
			 [System.String]::IsNullOrEmpty( $sPatternNumber ) ) {
			
			# Stopping cmdlet execution on failure
			$bStopProcessing = $true;
			Write-Error `
				-Message 'Error initializing the cmdlet.' `
				-TargetObject $LogDirectoryPath;
		}
		#endregion
	}
	
	process { 
		
		if ( $bStopProcessing -eq $true ) {
			continue;
		}
		
		try { # Unexpected error handling 
		
			if ( -not [System.IO.Directory]::Exists( $LogDirectoryPath ) ) {
				throw ( New-Object System.Exception( 'The specified directory not found.' ) );
			}
			
			if ( $PSCmdlet.ShouldProcess( "$LogDirectoryPath", "Get statistics from RoboCopy log files located in the directory." ) ) { # ShouldProcess block
			
				#region Discovering log files located under source directory
				$aItems = $null;
				if ( [System.String]::IsNullOrEmpty( $Filter ) ) {
					$aItems = [System.Array] ( Get-ChildItem -File -Recurse -Path $LogDirectoryPath -ErrorVariable oError );
				} else {
					$aItems = [System.Array] ( Get-ChildItem -File -Recurse -Path $LogDirectoryPath -Filter $Filter -ErrorVariable oError );
				}
				
				if ( $oError.Count -gt 0 ) {
					throw ( New-Object System.Exception( 'Error discovering log files.' ) );
				}
				
				if ( ( $aItems -eq $null ) -or ( $aItems.Count -le 0 ) ) {
					# Skipping to next log directory from pipeline, 
					# If there's no errors and no items found
					Write-Warning -Message "No appropriate files found under the specified directory '$LogDirectoryPath'.";
					continue;
				}
				#endregion
				
				#region Extracting full paths from files list
				$aFileList = [System.Array] ( $aItems | select -ExpandProperty FullName );
				if ( ( $aFileList -eq $null ) -or ( $aFileList.Count -le 0 ) ) {
					throw ( New-Object System.Exception( 'Error extracting files full paths from discovered log files.' ) );
				}
				#endregion
				
				#region Initializing summary object
				$oSummary = New-Object PSObject -ErrorVariable oError -Property @{

						DirectoriesTotal    = [System.Int32]  ( 0 )
						DirectoriesCopied   = [System.Int32]  ( 0 )
						DirectoriesSkipped  = [System.Int32]  ( 0 )
						DirectoriesMismatch = [System.Int32]  ( 0 )
						DirectoriesFailed   = [System.Int32]  ( 0 )
						DirectoriesExtras   = [System.Int32]  ( 0 )
						
						FilesTotal          = [System.Int32]  ( 0 )
						FilesCopied         = [System.Int32]  ( 0 )
						FilesSkipped        = [System.Int32]  ( 0 )
						FilesMismatch       = [System.Int32]  ( 0 )
						FilesFailed         = [System.Int32]  ( 0 )
						FilesExtras         = [System.Int32]  ( 0 )
						
						BytesTotal          = [System.Double] ( 0 )
						BytesCopied         = [System.Double] ( 0 )
						BytesSkipped        = [System.Double] ( 0 )
						BytesMismatch       = [System.Double] ( 0 )
						BytesFailed         = [System.Double] ( 0 )
						BytesExtras         = [System.Double] ( 0 )
						
					} | select `
						DirectoriesTotal, DirectoriesCopied, DirectoriesSkipped, DirectoriesMismatch, DirectoriesFailed, DirectoriesExtras, `
						FilesTotal, FilesCopied, FilesSkipped, FilesMismatch, FilesFailed, FilesExtras, `
						BytesTotal, BytesCopied, BytesSkipped, BytesMismatch, BytesFailed, BytesExtras;

				if ( ( $oSummary -eq $null ) -or ( $oError.Count -gt 0 ) ) {
					throw ( New-Object System.Exception( 'Unable to initialize summary variable.' ) );
				}
				#endregion

				#region Discovered files processing
				foreach ( $sFilePath in $aFileList ) { # Discovered files processing loop

					try { # Discovered file processing
					
						#region Loading file content
						$oContent = [System.Array] ( Get-Content -Path $sFilePath -ErrorVariable oError );
						if ( ( $oContent -eq $null ) -or ( $oError.Count -gt 0 ) ) {
							throw ( New-Object System.Exception( "Unable to get content from the file." ) );
						}
						#endregion

						#region Parsing file content
						for ( $iLineIdx = 0; $iLineIdx -lt $oContent.Count; $iLineIdx++ ) { # Parsing file lines loop
							
							if ( [Regex]::IsMatch( $oContent[ $iLineIdx ], $sPatternHeader, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase ) ) { # Summary block processing
								# Next lines should describes summary for dirs, files, bytes and times
								
								if ( ( $iLineIdx + 3 ) -ge $oContent.Count ) {
									throw ( New-Object System.Exception( 'Summary block is shoter than exptected.' ) );
								}
								
								#region Processing dirs summary line
								try {
									if ( -not [Regex]::IsMatch( $oContent[ $iLineIdx + 1 ], $sPatternDirs, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase ) ) {
										throw ( New-Object System.Exception( 'The line is not match with the corresponding pattern.' ) );
									}
									
									$oMatches = [Regex]::Matches( $oContent[ $iLineIdx + 1 ], $sPatternNumber, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase )
									if ( ( $oMatches -eq $null ) -or ( $oMatches.Count -ne 6 ) ) {
										throw ( New-Object System.Exception( 'Regular expression parser has returned a null-value or the returned value set count is not meet with the requirements.' ) );
									}
									
									$oSummary.DirectoriesTotal    += [Convert]::ToInt32( $oMatches[0].Value );
									$oSummary.DirectoriesCopied   += [Convert]::ToInt32( $oMatches[1].Value );
									$oSummary.DirectoriesSkipped  += [Convert]::ToInt32( $oMatches[2].Value );
									$oSummary.DirectoriesMismatch += [Convert]::ToInt32( $oMatches[3].Value );
									$oSummary.DirectoriesFailed   += [Convert]::ToInt32( $oMatches[4].Value );
									$oSummary.DirectoriesExtras   += [Convert]::ToInt32( $oMatches[5].Value );
									
								} catch {				
									throw ( New-Object System.Exception( "Error parsing directories statistics line. $($_.Exception.Message)", $_.Exception ) );
								}
								#endregion		
								
								
								#region Processing files summary line
								try {
									if ( -not [Regex]::IsMatch( $oContent[ $iLineIdx + 2 ], $sPatternFiles, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase ) ) {
										throw ( New-Object System.Exception( 'The line is not match with the corresponding pattern.' ) );
									}

									$oMatches = [Regex]::Matches( $oContent[ $iLineIdx + 2 ], $sPatternNumber, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase )
									if ( ( $oMatches -eq $null ) -or ( $oMatches.Count -ne 6 ) ) {
										throw ( New-Object System.Exception( 'Regular expression parser has returned a null-value or the returned value set count is not meet with the requirements.' ) );
									}
									
									$oSummary.FilesTotal    += [Convert]::ToInt32( $oMatches[0].Value );
									$oSummary.FilesCopied   += [Convert]::ToInt32( $oMatches[1].Value );
									$oSummary.FilesSkipped  += [Convert]::ToInt32( $oMatches[2].Value );
									$oSummary.FilesMismatch += [Convert]::ToInt32( $oMatches[3].Value );
									$oSummary.FilesFailed   += [Convert]::ToInt32( $oMatches[4].Value );
									$oSummary.FilesExtras   += [Convert]::ToInt32( $oMatches[5].Value );
									
								} catch {
									throw ( New-Object System.Exception( "Error parsing files statistics line. $($_.Exception.Message)", $_.Exception ) );
								}
								#endregion
								
								
								#region Processing bytes summary line
								try {
									#region Parsing the line
									if ( -not [Regex]::IsMatch( $oContent[ $iLineIdx + 3 ], $sPatternBytes, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase ) ) {
										throw ( New-Object System.Exception( 'The line is not match with the corresponding pattern.' ) );
									}
									
									$oMatches = [Regex]::Matches( $oContent[ $iLineIdx + 3 ], $sPatternNumber, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase )
									if ( ( $oMatches -eq $null ) -or ( $oMatches.Count -ne 6 ) ) {
										throw ( New-Object System.Exception( 'Regular expression parser has returned a null-value or the returned value set count is not meet with the requirements.' ) );
									}
									#endregion
									
									#region Total bytes
									$nBytesTotal = ConvertTo-Bytes -Value ( $oMatches[0].Value ) -ErrorVariable oError
									if ( ( $nBytesTotal -eq $null ) -or ( $oError.Count -gt 0 ) -or ( $nBytesTotal -lt 0 ) ) {
										throw ( New-Object System.Exception( "Incorrect value was returned from ConvertTo-Bytes cmdlet while attempting to convert the value '$($oMatches[0].Value)' to bytes for BytesTotal property." ) );
									}				
									$oSummary.BytesTotal += $nBytesTotal;
									#endregion
									
									#region Copied bytes
									$nBytesCopied = ConvertTo-Bytes -Value ( $oMatches[1].Value ) -ErrorVariable oError
									if ( ( $nBytesCopied -eq $null ) -or ( $oError.Count -gt 0 ) -or ( $nBytesCopied -lt 0 ) ) {
										throw ( New-Object System.Exception( "Incorrect value was returned from ConvertTo-Bytes cmdlet while attempting to convert the value '$($oMatches[1].Value)' to bytes for BytesCopied property." ) );
									}				
									$oSummary.BytesCopied += $nBytesCopied;
									#endregion
									
									#region Skipped bytes
									$nBytesSkipped = ConvertTo-Bytes -Value ( $oMatches[2].Value ) -ErrorVariable oError;
									if ( ( $nBytesSkipped -eq $null ) -or ( $oError.Count -gt 0 ) -or ( $nBytesSkipped -lt 0 ) ) {
										throw ( New-Object System.Exception( "Incorrect value was returned from ConvertTo-Bytes cmdlet while attempting to convert the value '$($oMatches[2].Value)' to bytes for BytesSkipped property." ) );
									}				
									$oSummary.BytesSkipped += $nBytesSkipped;
									#endregion
									
									#region Mismatched bytes
									$nBytesMismatch = ConvertTo-Bytes -Value ( $oMatches[3].Value ) -ErrorVariable oError;
									if ( ( $nBytesMismatch -eq $null ) -or ( $oError.Count -gt 0 ) -or ( $nBytesMismatch -lt 0 ) ) {
										throw ( New-Object System.Exception( "Incorrect value was returned from ConvertTo-Bytes cmdlet while attempting to convert the value '$($oMatches[3].Value)' to bytes for BytesMismatch property." ) );
									}
									$oSummary.BytesMismatch += $nBytesMismatch;
									#endregion
									
									#region Failed bytes
									$nBytesFailed = ConvertTo-Bytes -Value ( $oMatches[4].Value ) -ErrorVariable oError;
									if ( ( $nBytesFailed -eq $null ) -or ( $oError.Count -gt 0 ) -or ( $nBytesFailed -lt 0 ) ) {
										throw ( New-Object System.Exception( "Incorrect value was returned from ConvertTo-Bytes cmdlet while attempting to convert the value '$($oMatches[4].Value)' to bytes for BytesFailed property." ) );
									}				
									$oSummary.BytesFailed += $nBytesFailed;
									#endregion
									
									#region Extra bytes
									$nBytesExtras = ConvertTo-Bytes -Value ( $oMatches[5].Value ) -ErrorVariable oError ;
									if ( ( $nBytesExtras -eq $null ) -or ( $oError.Count -gt 0 ) -or ( $nBytesExtras -lt 0 ) ) {
										throw ( New-Object System.Exception( "Incorrect value was returned from ConvertTo-Bytes cmdlet while attempting to convert the value '$($oMatches[5].Value)' to bytes for BytesExtras property." ) );
									}
									$oSummary.BytesExtras += $nBytesExtras;
									#endregion
									
								} catch {
									throw ( New-Object System.Exception( "Error parsing bytes statistics line. $($_.Exception.Message)", $_.Exception ) );
								}
								#endregion
								
								break; # All data has been extracted breaking the loop
								
							} # Summary block processing
							
						} # Parsing file lines loop
						#endregion
					
					} catch { # Discovered file processing
						
						Write-Error `
							-Message "Unable to process a log file '$sFilePath'. $($_.Exception.Message)" `
							-TargetObject $sFilePath `
							-Exception ($_.Exception);
						continue;
						
					} # Discovered file processing
					
				} # Discovered files processing loop
				#endregion
				
				return $oSummary;
			} # ShouldProcess block
			
		} catch { # Unexpected error handling
		
			Write-Error `
					-Message "Unable to extract summary info from files located at the directory '$LogDirectoryPath'. $($_.Exception.Message)" `
					-Exception ( $_.Exception ) `
					-TargetObject $LogDirectoryPath;
			continue;
			
		} # Unexpected error handling 
	} 
	
	end {  }
}