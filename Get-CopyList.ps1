# © 2016, Aleksey Ivanov

. .\Get-ChildDirectoryRelativePath.ps1

<#
.Synopsis
   Gets copy list from file
.DESCRIPTION
   The Get-CopyList cmdlet retreives list of source, destination and regular expression filter from a specified file and gets all child directories for source parent directory that matches a regular expression filter.
   This regexp filter might have multiple subdirectories.
.EXAMPLE
   Get-CopyList -Path 'c:\tmp\copy-list.csv'
   This command loads a list of source, destination and regular expression filter from the specified file and resolve the pair of SourceDirectory\RegExp to all existing paths.
.INPUTS
   [System.String] – Path to a csv-file from which the list should be loaded.
   The file should contain the following fields: 
   Source      – goes for source parent directory
   Destination – goes for destination parent directory
   Filter      – goes for regular expression filter for relative path under source/destination directory
.OUTPUTS
   [System.Array] on success.
   NULL           on failure.
.NOTE
    This cmdlet relies on Get-ChildDirectoryRelativePath cmdlet.
#>
function Get-CopyList
{
	#region Settings
    [CmdletBinding( SupportsShouldProcess = $true, 
                    ConfirmImpact         = 'Low' )]

    [OutputType( [System.Array] )]
	#endregion
    
	#region Parameters
    param (
        # Path to rules CSV-file
		# The file should meet the following header:
		# Source,Destination,Filter,LastWriteDateStart,LastWriteDateEnd
		#
		# Source             – source directory.
		# Destination        - destination directory.
		# Filter             - regular expression filter string for child directory path. Might contain backslashes.
		# LastWriteDateStart - last write DateTime string for lowest child directory from which directory should be included
		# LastWriteDateEnd   - last write DateTime string for lowest child directory from which directory shouldn't be included
        [Parameter( 
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true, 
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [Alias( 'FilePath' )]
        [System.String]
        $Path
    )
	#endregion

    begin {  }

    process {

		# Resultant array of object representing source directory, destination directory and relative path (if exists)
        $aResultantPath = @();
		
        try { # Processing
         
            if ( $PSCmdlet.ShouldProcess( "$Path", "Get relative path for sources listed in the file." ) ) {
                
				#region Loading copy rules
                $aCopyRule = [System.Array] ( Import-Csv -Path $Path -ErrorVariable oError );
				if ( $oError.Count -gt 0 ) {
					
					Write-Error -Message 'Error calling Import-Csv cmdlet while attempting to load copy rules file.' -TargetObject $Path;
					return;
				}
				
                if ( ( $aCopyRule -eq $null ) -or ( $aCopyRule.Count -le 0 ) ) {
					Write-Error -Message 'No copy rules found in the file specified.' -TargetObject $Path;
					return;
                }
				#endregion

                for ( [System.Int32] $iRuleIdx = 0; $iRuleIdx -lt $aCopyRule.Count; $iRuleIdx++ ) {
					
					#region Checking current copy rule
					if ( $aCopyRule[ $iRuleIdx ] -eq $null ) {
						Write-Error -Message "Copy rule with index $iRuleIdx is null." -TargetObject $Path;
						continue;
					}
					
					if ( [System.String]::IsNullOrEmpty( $aCopyRule[ $iRuleIdx ].Source ) ) { # Source directory path
						Write-Error -Message "Source directory of copy rule with index $iRuleIdx is null." -TargetObject ( $aCopyRule[ $iRuleIdx ] );
						continue;
					}
					
					if ( [System.String]::IsNullOrEmpty( $aCopyRule[ $iRuleIdx ].Destination ) ) { # Destination directory path
						Write-Error -Message "Destination directory of copy rule with index $iRuleIdx is null." -TargetObject ( $aCopyRule[ $iRuleIdx ] );
						continue;
					}
					#endregion
					
					#region Generating copy rule object(s)
					if ( -not [System.String]::IsNullOrEmpty( $aCopyRule[ $iRuleIdx ].Filter ) ) {
	                    
						#region Processing rule with multiple child directories
						
						#region Calculating last write date boudaries
						$oLastWriteDateStart = $null;
						$oLastWriteDateEnd   = $null;
						
						if ( -not [System.String]::IsNullOrEmpty( $aCopyRule[ $iRuleIdx ].LastWriteDays ) ) {
							# Calculating last write date boundaries, if moving copy windows specified.
						
							$iLastWriteDays = 0;				
							
							#region Validating value
							try {							
								$iLastWriteDays = [System.Convert]::ToInt32( $aCopyRule[ $iRuleIdx ].LastWriteDays )
								if ( $iLastWriteDays -le 0 ) {
									throw ( New-Object System.Exception( 'The value should by greater than zero.' ) );
								}
								
							} catch {
							
								Write-Error `
									-Message "Error processing LastWriteDays parameter. $($_.Exception.Message)" `
									-Exception ( $_.Exception ) `
									-TargetObject ( $aCopyRule[ $iRuleIdx ] );
								continue;
							}
							#endregion
						
							$oLastWriteDateEnd = Get-Date -ErrorVariable oError;
							if ( ( $oLastWriteDateEnd -eq $null ) -or ( $oError.Count -gt 0 ) ) {							
								Write-Error `
									-Message 'Error calling Get-Date cmdlet while attempting to get current date for last write date end boundary.' `
									-TargetObject ( $aCopyRule[ $iRuleIdx ] );
								continue;
							}
								
							$oLastWriteDateStart = $oLastWriteDateEnd.AddDays( -$iLastWriteDays );
							if ( $oLastWriteDateStart -eq $null ) {
								Write-Error `
									-Message 'Error calculating last write date start boundary. The value is NULL.' `
									-TargetObject ( $aCopyRule[ $iRuleIdx ] );
								continue;
							}
							
						} else {
							# Passing through last write date boundaries from the rule
							$oLastWriteDateStart = $aCopyRule[ $iRuleIdx ].LastWriteDateStart;
							$oLastWriteDateEnd = $aCopyRule[ $iRuleIdx ].LastWriteDateEnd;
						}
						#endregion
						
						#region Discovering relative paths for parent directory using filters
                        $aRelativePath = [System.Array] ( Get-ChildDirectoryRelativePath `
								-Directory ( $aCopyRule[ $iRuleIdx ].Source ) `
								-Filter ( $aCopyRule[ $iRuleIdx ].Filter ) `
								-LastWriteDateStart $oLastWriteDateStart `
								-LastWriteDateEnd $oLastWriteDateEnd `
								-ErrorVariable oError
							);
							
						if ( $oError.Count -gt 0 ) {
							Write-Error `
								-Message 'Error calling Get-ChildDirectoryRelativePath cmdlet while attempting to discover child directories relative path.' `
								-TargetObject ( $aCopyRule[ $iRuleIdx ] );
						}
						
                        if ( $aRelativePath -eq $null ) {
							# No relative paths found. Skipping to next copy rule.
                            continue;
                        }
						#endregion

                        for ( [System.Int32] $iRelativePathIdx = 0; $iRelativePathIdx -lt $aRelativePath.Count; $iRelativePathIdx++ ) {
                            # Object that represents resultant set of source directory, destination directory and relative path (if exists)
							
							#region Generating separate copy rule object for each discovered relative path
							if ( [System.String]::IsNullOrEmpty( $aRelativePath[ $iRelativePathIdx ] ) ) { # Relative path
								Write-Error 
									-Message 'Relative path to child directory in null.' `
									-TargetObject ( $aCopyRule[ $iRuleIdx ] );
								continue;
							}
														
							#region Generating source and destination directories full path
							$sSourceDirectoryFullPath      = $null;
							$sDestinationDirectoryFullPath = $null;
							try {
							
								$sSourceDirectoryFullPath = [System.String]::Format( "{0}\{1}", $aCopyRule[ $iRuleIdx ].Source, $aRelativePath[ $iRelativePathIdx ] );
								if ( [System.String]::IsNullOrEmpty( $sSourceDirectoryFullPath ) ) {
									throw ( New-Object System.Exception( "A null-value was returned from System.String.Format() while generating source directory full path." ) );
								}
								
	    						$sDestinationDirectoryFullPath = [System.String]::Format( "{0}\{1}", $aCopyRule[ $iRuleIdx ].Destination, $aRelativePath[ $iRelativePathIdx ] );
								if ( [System.String]::IsNullOrEmpty( $sDestinationDirectoryFullPath ) ) {
									throw ( New-Object System.Exception( "A null-value was returned from System.String.Format() while generating destination directory full path." ) );
								}
								
							} catch {
							
								Write-Error `
									-Message 'Error adding current relative path to source/destination directory path.' `
									-TargetObject ( $aRelativePath[ $iRelativePathIdx ] );
								continue;
							}
							#endregion
							
							#region Initializing copy rule object
                            $oCopyRule = New-Object PSObject -Property @{ Source       = $sSourceDirectoryFullPath
										                                  Destination  = $sDestinationDirectoryFullPath } | select Source, Destination;
                            if ( $oCopyRule -eq $null ) {								
								Write-Error `
									-Message 'Unable to create copy rule object from source and destination directory' `
									-TargetObject ( $aRelativePath[ $iRelativePathIdx ] );
								continue;
                            }
							#endregion

                            $aResultantPath += $oCopyRule;
							#endregion
                        }
						#endregion

                    } else {
						#region Generating copy rule object for rules with empy filter
                        $oCopyRule = New-Object PSObject -Property @{ Source      = $aCopyRule[ $iRuleIdx ].Source
                            										  Destination = $aCopyRule[ $iRuleIdx ].Destination } | select Source, Destination;
                        if ( $oCopyRule -eq $null ) {
                            Write-Error `
								-Message 'Unable to create copy rule object from source and destination directory.' `
								-TargetObject ( $aCopyRule[ $iRuleIdx ] );
							continue;
                        }
						
                        $aResultantPath += $oCopyRule;
						#endregion
                    }   
					#endregion
                }

                return $aResultantPath;
            }
			
        } catch { # Processing

            Write-Error `
                -Message "An unknown exception occured while executing Get-CopyList 'process {}' block." `
                -Exception ( $_.Exception ) `
				-TargetObject $Path;
			return;
        }
    }
    
    end {  }
}