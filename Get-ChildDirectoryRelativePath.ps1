# © 2016, Aleksey Ivanov

<#
.Synopsis
   Gets relative paths for specified source directory.
.DESCRIPTION
   The Get-ChildDirectoryRelativePath cmdlet gets relative paths for a specified source/parent directory that matches a specified regular expression string.
.EXAMPLE
   Get-ChildDirectoryRelativePath -Directory 'd:\data\source' -Filter '\d+\.\d+\.\d+\..+\\Binaries'
   This command gets relative paths for parent directory 'd:\data\source' that matches the regexp with depth of two subfolders, first of that matches X.X.X.* pattern and secound matches name 'Binaries'.
.EXAMPLE
   Get-ChildDirectoryRelativePath -Directory 'd:\data\source' -Filter '\d+\.\d+\.\d+\..+\\(Binaries|Setup)'
   This command gets relative paths for parent directory 'd:\data\source' that matches the regexp with depth of two subfolders, first of that matches X.X.X.* pattern and secound matches names 'Binaries' or 'Setup'.
.EXAMPLE
   Get-ChildDirectoryRelativePath -Directory 'd:\data\source' -Filter '\d+\.\d+\.\d+\..+\\(Binaries|Setup)' -LastWriteDateStart '20 mar 2016'
   This command gets relative paths to child directory(-ies) that was modified AFTER 20 Mar 2016 0:00:00 for parent directory 'd:\data\source' that matches the regexp with depth of two subfolders, first of that matches X.X.X.* pattern and secound matches names 'Binaries' or 'Setup'.
.EXAMPLE
   Get-ChildDirectoryRelativePath -Directory 'd:\data\source' -Filter '\d+\.\d+\.\d+\..+\\(Binaries|Setup)' -LastWriteDateEnd '20 mar 2016'
   This command gets relative paths to child directory(-ies) that was modified BEFORE 20 Mar 2016 0:00:00 for parent directory 'd:\data\source' that matches the regexp with depth of two subfolders, first of that matches X.X.X.* pattern and secound matches names 'Binaries' or 'Setup'.
.EXAMPLE
   Get-ChildDirectoryRelativePath -Directory 'd:\data\source' -Filter '\d+\.\d+\.\d+\..+\\(Binaries|Setup)' -LastWriteDateStart '01 mar 2016' -LastWriteDateEnd '20 mar 2016 23:59:59'
   This command gets relative paths to child directory(-ies) that was modified BETWEEN 1 Mar 2016 0:00:00 and 20 Mar 2016 23:59:59 for parent directory 'd:\data\source' that matches the regexp with depth of two subfolders, first of that matches X.X.X.* pattern and secound matches names 'Binaries' or 'Setup'.
.EXAMPLE
   Get-ChildDirectoryRelativePath -Directory 'd:\data\source' -Filter '\d+\.\d+\.\d+\..+\\(Binaries|Setup)' -LastWriteDateStart ((Get-Date).AddDays(-7)) -LastWriteDateEnd (Get-Date)
   This command gets relative paths to child directory(-ies) that was modified during past seven (7) days for parent directory 'd:\data\source' that matches the regexp with depth of two subfolders, first of that matches X.X.X.* pattern and secound matches names 'Binaries' or 'Setup'.
.INPUTS
   [System.String] as source/parent directory path.
   [System.String] as regular expression filter.
   [System.String] as start date filter.
   [System.String] as end date filter.
.OUTPUTS
   [System.Array] – on success.
   NULL – if no subdirectory(-ies) found that meet specified filter(s).
   NULL & error – on failure.
#>
function Get-ChildDirectoryRelativePath {

	#region Settings
    [CmdletBinding( SupportsShouldProcess = $true, 
                    ConfirmImpact         = 'Low' )]
					
    [OutputType( [System.Array] )]
	#endregion

	#region Parameters
    param
    (
        # Parent directory full path for which child directory should be found
        [Parameter( Mandatory = $true )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        [Alias( 'ParentDirectory' )]
        [Alias( 'SourceDirectory' )]
        $Directory,

        # Regular expression filter for child directoy (-ies)
        [Parameter( Mandatory = $true )]
        [ValidateNotNullOrEmpty()]
        [System.String]
        [Alias( 'RegExpFilter' )]
        [Alias( 'RegExp' )]
        $Filter,
		
		# Last write start date and time
		# Acceptable values
		# * DateTime object 
		# * DateTime string ('1 Jan 2016', '01.01.2016', '01/01/2016')
		#   Values like '1 Jan 2016' are equals '1 Jan 2016 0:00:00'
		[Parameter( Mandatory = $false )]
		[System.Object]
		$LastWriteDateStart,
		
		# Last write end date and time
		# Acceptable values
		# * DateTime object 
		# * DateTime string ('1 Jan 2016', '01.01.2016', '01/01/2016')
		#   Values like '1 Jan 2016' are equals '1 Jan 2016 0:00:00'
		#   Commonly, to include all child directories that was modified after 1 Jan 1016, you prefer to use value like '1 Jan 2016 23:59:59' or '2 Jan 2016'
		[Parameter( Mandatory = $false )]
		[System.Object]
		$LastWriteDateEnd
    )
	#endregion

    begin {
		
		# Processing stop flag
		$bStopProcessing = $false;
		
        # Backslash symbol regexp definition
		$sBackslashRegexp = '\\';
		# Result object
		$aResultChildDirectoryRelativePath = $null;

		#region Last write date start time
		$oLastWriteDateStart = $null;
		if ( $LastWriteDateStart -ne $null ) { # If the parameter is specified
		
			if ( [System.String]::Compare( $LastWriteDateStart.GetType().FullName, 'System.String', $true) -eq 0 ) { # Converting date time strign to DateTime object
				
				if ( -not [System.String]::IsNullOrEmpty( $LastWriteDateStart ) ) { 
					# Making sure that the string is specified and not empty.
					# Empty strings means that the value is not set.
			
					try {
						$oLastWriteDateStart = Get-Date -Date $LastWriteDateStart;
						if ( $oLastWriteDateStart -eq $null ) {
							throw ( New-Object System.Exception( 'A null-value was returned from Get-Date cmdlet.') );
						}
						
					} catch {
					
						Write-Error `
							-Message "Error converting LastWriteDateStart string to DateTime object. $($_.Exception.Message)" `
							-TargetObject $LastWriteDateStart;
						$bStopProcessing = $true;
						return;
					}
				}
				
			} elseif ( [System.String]::Compare( $LastWriteDateStart.GetType().FullName, 'System.DateTime', $true ) -eq 0 ) {
				
				# Using specified DateTime object as is
				$oLastWriteDateStart = $LastWriteDateStart;
				
			} else { # Unacceptable object type
				
				Write-Error `
					-Message 'Unacceptable type of object for LastWriteDateStart parameter.' `
					-TargetObject $LastWriteDateStart;
				$bStopProcessing = $true;
				return;
			}			
		}
		#endregion
		
		#region Last write date end time
		$oLastWriteDateEnd = $null;
		if ( $LastWriteDateEnd -ne $null ) { # If the parameter is specified
			
			if ( [System.String]::Compare( $LastWriteDateEnd.GetType().FullName, 'System.String', $true ) -eq 0 ) { # Converting date time strign to DateTime object
				
				if ( -not [System.String]::IsNullOrEmpty( $LastWriteDateEnd ) ) {
					# Making sure that the string is specified and not empty.
					# Empty strings means that the value is not set.
					
					try {
						$oLastWriteDateEnd = Get-Date -Date $LastWriteDateEnd;
						if ( $oLastWriteDateEnd -eq $null ) {
							throw ( New-Object System.Exception( 'A null-value was returned from Get-Date cmdlet.' ) );
						}
						
					} catch {						
						Write-Error `
							-Message "Error converting LastWriteDateEnd string to DateTime object. $($_.Exception.Message)" `
							-TargetObject $LastWriteDateEnd;
						$bStopProcessing = $true;
						return;
					}
				}	
			
			} elseif ( [System.String]::Compare( $LastWriteDateEnd.GetType().FullName, 'System.DateTime', $true ) -eq 0 ) {
				
				# Using specified DateTime object as is
				$oLastWriteDateEnd = $LastWriteDateEnd;
			
			} else { # Unacceptable object type
				
				Write-Error `
					-Message 'Unacceptable type of object for LastWriteDateEnd parameter.' `
					-TargetObject $LastWriteDateEnd;
				$bStopProcessing = $true;
				return;
			}
		}
		#endregion
    }

    process {
        
		if ( $bStopProcessing ) { # Skipping pipeline if stop flag set
			continue ;
		}
		
        try { # Processing

            if ( $PSCmdlet.ShouldProcess( "$SourceDirectory", "Get child directories using regexp filter '$Filter'" ) ) {

                #region Getting backslashes position in filter string
                # Resultant backslashes indexes array
                $aDirectoryNameStartIndex = @();

                # Initializing first directory name index
                $iDirectoryNameStartIndex = 0;

                # Directory name start index search loop
                while ( $iDirectoryNameStartIndex -gt -1 ) {

                    # Searhing for backslashes
                    $iBackslashIndex = $Filter.IndexOf( $sBackslashRegexp,  $iDirectoryNameStartIndex );
                    if ( $iBackslashIndex -eq -1 ) {
                        # Assuming it's last directory name if no backslash found
                        $aDirectoryNameStartIndex += $iDirectoryNameStartIndex;
                        $iDirectoryNameStartIndex = -1;
                        continue;
                    }

                    # Adding found backslash index to resultant backslashes index array
                    $aDirectoryNameStartIndex += $iBackslashIndex;
    
                    # Setting next search substring using found index + backslash regexp length
                    $iDirectoryNameStartIndex = $iBackslashIndex + $sBackslashRegexp.Length;
    
                    # Signaling search loop to stop if we're reach the end of filter string
                    if ( $iDirectoryNameStartIndex -ge $Filter.Length ) {
                        $iDirectoryNameStartIndex = -1;
                    }
					
                } # Directory name start index search loop
                #endregion

                #region Splitting filter string to directory regexp list
                # Resultant directory names array
                $aDirectoryName = @();

                # Directory name start index
                $iDirectoryNameStartIndex = -1;

                # Directory name end index
                $iDirectoryNameEndIndex   = -1;

                # Directory name retreive loop
                for ( [System.Int32] $iDirectoryNameIdx = 0; $iDirectoryNameIdx -lt $aDirectoryNameStartIndex.Count; $iDirectoryNameIdx++ ) {

                    if ( $iDirectoryNameIdx -eq 0 ) {
        
                        # Setting directory name start and end indexes for the first directory in the filter string
                        $iDirectoryNameStartIndex = 0;
						
						if ( ( $aDirectoryNameStartIndex.Count -eq 1 ) -and 
						     ( $aDirectoryNameStartIndex[0]    -eq 0 ) ) {
						
							# There's only one directory name in filter
							$iDirectoryNameEndIndex = $Filter.Length;
							
						} else {
							$iDirectoryNameEndIndex = $aDirectoryNameStartIndex[ $iDirectoryNameIdx ];
						}

                    } elseif ( $iDirectoryNameIdx -eq ( $aDirectoryNameStartIndex.Count - 1 ) ) {
        
                        # Setting directory name start and end indexes for the last directory in the filter string
                        $iDirectoryNameStartIndex = $aDirectoryNameStartIndex[ $iDirectoryNameIdx ];
                        $iDirectoryNameEndIndex   = $Filter.Length;

                    } else {
                        # Setting directory name start and end indexes for all others directories in the filter strint
                        $iDirectoryNameStartIndex = $aDirectoryNameStartIndex[ $iDirectoryNameIdx - 1 ] + $sBackslashRegexp.Length;
                        $iDirectoryNameEndIndex   = $aDirectoryNameStartIndex[ $iDirectoryNameIdx     ];
                    }

                    # Checking directory name length
                    $iDirectoryNameLength = $iDirectoryNameEndIndex - $iDirectoryNameStartIndex
                    if ( $iDirectoryNameLength -gt 0 ) { # Extracting directory name if present
                        
						$sTmpSubstring = $null;

                        try {
							$sTmpSubstring = $Filter.Substring( $iDirectoryNameStartIndex, $iDirectoryNameLength )	;
							
						} catch {
						
							Write-Error `
								-Message 'Exception calling System.String.SubString() while attempting to extract a directory name from the filter string.' `
								-Exception ( $_.Exception ) `
								-TargetObject $Filter;
							$bStopProcessing = $true;
							return;
						}
						
						# Adding extracted directory name (if it's not null) to the resultant directory names array
                        if ( -not [System.String]::IsNullOrEmpty( $sTmpSubstring ) ) {
                            $aDirectoryName += $sTmpSubstring;
                        }
                    }

                    # Moving to next directory
                    $iDirectoryNameStartIndex = $aDirectoryNameStartIndex[ $iDirectoryNameIdx ] + $sBackslashRegexp.Length;
					
                } # Directory name retreive loop
                #endregion

                #region Generating matching directory list
                # Initializing resultant directory path list using source directory path as a root path
                $aChildDirectoryRelativePath = [System.Array] ('.');

                # Directory search loop for each subdirectory name in filter list
                for ( [System.Int32] $iDirectoryNameIdx = 0; $iDirectoryNameIdx -lt $aDirectoryName.Count; $iDirectoryNameIdx++ ) {
    
                    # Temporary variable for resultant directory path list
                    $aTmpChildDirectoryRelativePath = @();

                    # Subdirectory search loop
					for ( [System.Int32] $iRelativePathIdx = 0; $iRelativePathIdx -lt $aChildDirectoryRelativePath.Count; $iRelativePathIdx++ ) {
        										                        	
						if ( [System.String]::IsNullOrEmpty( $aChildDirectoryRelativePath[ $iRelativePathIdx ] ) ) {
							
							# If current relative path is null, issue a warning and skip to next relative path in array
							Write-Warning -Message 'Current child directory relative path has a null value.';
							continue;
						}
						
						#region Getting child items from parent directory
						$sRootDirectoryPath = ''
						
						try {
							$sRootDirectoryPath = [System.String]::Format( "{0}\{1}", $Directory, $aChildDirectoryRelativePath[ $iRelativePathIdx ] );
							if ( [System.String]::IsNullOrEmpty( $sRootDirectoryPath ) ) {
								throw ( New-Object System.Exception( 'A null-value was returned from System.String.Format() while attempting to generate parent directory path for child directory relative path discovery.' ) );
							}
							
						} catch {
						
							Write-Error `
								-Message 'Error calling System.String.Format() while attempting to generate parent directory path for child directory relative path discovery.' `
								-Exception ( $_.Exception ) `
								-TargetObject ( $aChildDirectoryRelativePath[ $iRelativePathIdx ] );
							$bStopProcessing = $true;
							return;
						}
										
						$aChildItem = [System.Array] ( Get-ChildItem -Path $sRootDirectoryPath -ErrorVariable oError );
						if ( $oError.Count -gt 0 ) {
							
							Write-Error `
								-Message 'Error calling Get-ChildItem cmdlet while attempting to discover child items for specified parent folder.' `
								-TargetObject $sRootDirectoryPath;
							$bStopProcessing = $true;
							return;
						}
						
						if ( ( $aChildItem -eq $null ) -or ( $aChildItem.Count -le 0 ) ) {
							# No child item(s) found. Skipping to next parent directory
							continue;
						}
						#endregion
						
						#region Filtering child directories using regular expression and last write date filters
						$aFilteredChildDirectory = @();
						
						for ( [System.Int32] $iChildItemIdx = 0; $iChildItemIdx -lt $aChildItem.Count; $iChildItemIdx ++ ) {
						
							if ( $aChildItem[ $iChildItemIdx ] -eq $null ) {
								Write-Warning -Message 'A child directory object is null. Skipping to next one.';
								continue;
							}
							
							#region Checking if the item is directory
							if ( -not $aChildItem[ $iChildItemIdx ].PSIsContainer ) {
								# The item isn't a directory. Skipping to next item.
								continue;
							}
							#endregion
							
							#region Checking it item's name matches regular expression
							if ( -not ( $aChildItem[ $iChildItemIdx ].Name -match $aDirectoryName[ $iDirectoryNameIdx ] ) ) {
								# The item's name didn't match. Skipping to next item.
								continue;
							}
							#endregion
						
							#region Fitlering by last write date
							# Should apply date filter only no the childest directory in path
							if ( $iDirectoryNameIdx -eq ( $aDirectoryName.Count - 1 ) ) {
							
								#region Filtering source directory by start date
							    if ( ( $oLastWriteDateStart -ne $null ) -and 
							         ( $aChildItem[ $iChildItemIdx ].LastWriteTime -lt $oLastWriteDateStart ) ) {
							        
							        # Current source directory should be skipped, if start date filter is set and current directory last write time is earlier than the start date
							        continue;
							    }
								#endregion
							    
							    #region Filtering source directory by end date
							    if ( ( $oLastWriteDateEnd -ne $null ) -and 
							         ( $aChildItem[ $iChildItemIdx ].LastWriteTime -gt $oLastWriteDateEnd ) ) {
							            
							        # Current source directory should be skipped, if end date filter is set and current directory last write time is latter than the stop date
							        continue;
							    }
								#endregion
							}
							#endregion
							
							# The subfolder meets data filtering requirements
							$aFilteredChildDirectory += $aChildItem[ $iChildItemIdx ];								
						}
						
						if ( $aFilteredChildDirectory.Count -le 0 ) {
							# Matched subdirectory(-ies) not found
							$aChildItem = $null;
							
						} else {
							# Matched subdirectory(-ies) found
							$aChildItem = $aFilteredChildDirectory;
						}
						
						# If no child subdirectory found for specified filter, goto next element
                        if ( $aChildItem -eq $null ) { 
                            continue;
                        }
						#endregion
                                
                        #region Concatenating found subdirectory names with parent directory path in subdirectory filter
                        foreach ( $sChildDirectory in $aChildItem ) {

                            if ( [System.String]::Compare( $aChildDirectoryRelativePath[ $iRelativePathIdx ], '.', $true ) -eq 0 ) {
							
                                $aTmpChildDirectoryRelativePath += $sChildDirectory.Name;
								
                            } else {
							
								$sTmpChildDirectoryRelativePath = $null;

								try {
									$sTmpChildDirectoryRelativePath = [System.String]::Format( "{0}\{1}", 
											$aChildDirectoryRelativePath[ $iRelativePathIdx ], 
											$sChildDirectory.Name 
										);

									if ( [System.String]::IsNullOrEmpty( $sTmpChildDirectoryRelativePath ) ) {
										throw ( New-Object System.Exception( "A null-value was returned from System.String.Format() while attempting to generate temporary child directory relative path." ) );
									}
									
								} catch {
									
									Write-Error `
										-Message 'Error calling System.String.Format() while attempting to concatenate found subdirectory name with parent directory path in subfolder filter.' `
										-Exception ( $_.Exception ) `
										-TargetObject ( $sChildDirectory.Name );
									$bStopProcessing = $true;
									return;
								}								
																
								$aTmpChildDirectoryRelativePath += $sTmpChildDirectoryRelativePath;
                            }
                        }
						#endregion
                    }

                    # Generating resultant deirectory path list for next iteration
                    $aChildDirectoryRelativePath = $aTmpChildDirectoryRelativePath;
					
                }# Directory search loop for each subdirectory name in filter list
                #endregion
				
				#region Returning results
				if ( 	( $aChildDirectoryRelativePath.Count -eq 0 ) -or 
						
						# If the only matched directory in current directory '.' (dot), then the cmdlet returns NULL.
						# It's not an error, 'cause no child directory was found.
						( ( $aChildDirectoryRelativePath.Count -eq 1 ) -and ( [System.String]::Compare( $aChildDirectoryRelativePath[0], '.', $true ) -eq 0 ) ) ) { 
				
					# Setting resultant object to NULL
					$aChildDirectoryRelativePath = $null;
				}
				
		        return $aChildDirectoryRelativePath;
				#endregion
            }

        } catch { # Processing 

            Write-Error `
                -Message "An unknown exception occured while executing Get-ChildDirectoryRelativePath 'process {}' block." `
                -Exception ( $_.Exception ) `
				-TargetObject $Directory;
			$bStopProcessing = $true;
			return;
		}
		
    } # Process block

    end { }
}