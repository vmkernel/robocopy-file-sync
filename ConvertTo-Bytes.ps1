# Initialy created by Aleksey Ivanov, 2016.

<#
.SYNOPSIS
	Converts size descriptor string to bytes
	
.DESCRIPTION
	The ConvertTo-Bytes cmdlet converts size descriptior string (e.g.: '1.6 k', '14.88 m', '16 g') to size in bytes.
	The cmdlet accepts values from the pipeline.
	
.EXAMPLE
	ConvertTo-Bytes -Value '1.23 m'
	This command converts the string '1.23 m' that describes size in 1.23 MB to it's equivalent size in bytes (System.Double).
	
	ConvertTo-Bytes -Value '12 k'
	This command converts the string '12 k' that describes size in 12 KB to it's equivalent size in bytes (System.Double).
	
	ConvertTo-Bytes -Value '1024'
	This command converts the string '1024' that describes size in 1024 bytes to it's equivalent size in bytes (System.Double).
	
.INPUTS
	[System.String]
	
.OUTPUTS
	[System.Double]	
#>
function ConvertTo-Bytes {
	
	[CmdLetBinding()]
	
	param (
		# Value that should be converted
		[Parameter( Mandatory = $true, 
					ValueFromPipeline = $true,
        			ValueFromPipelineByPropertyName = $true )]
		[ValidateNotNullOrEmpty()]
		[System.String] $Value
	)
	
	begin { 
		
		# Result variable (size in bytes)
		$iSizeBytes = 0;
		
		# Fatal error flag
		$bStopProcessing = $false;
		
		# Format provider object
		$oFormatProvider = $null;
		
		#region Initializing format provider
		try {
			$oFormatProvider = New-Object System.Globalization.NumberFormatInfo;
			if ( $oFormatProvider -eq $null ) {
				throw ( New-Object System.Exception( 'A null-value returned from System.Globalization.NumberFormatInfo() constructor while attempting to initialize format provider.' ) );
			}
			$oFormatProvider.NumberDecimalSeparator = '.';
			
		} catch {
		
			$bStopProcessing  = $true;
			Write-Error `
				-Message "Error occured while attempting to initialize the cmdlet. $($_.Exception.Message)" `
				-Exception ( $_.Exception );
		}
		#endregion
	}
	
	process {
	
		if ( $bStopProcessing  ) { 
			continue; 
		}
	
		try { # Processing block
		
			#region Normalizing input value
			# Removing spaces
			$sValueNormalized = $Value.Replace( ' ', '' );
			if ( [System.String]::IsNullOrEmpty( $sValueNormalized ) ) {
				throw ( New-Object System.Exception( 'A null-value returned from System.String.Replace() while attempting to remove spaces from input value.' ) );
			}
			
			# Replacing decimal delimeter from comma sign to dot dign
			$sValueNormalized = $sValueNormalized.Replace( ',', '.' );
			if ( [System.String]::IsNullOrEmpty( $sValueNormalized ) ) {
				throw ( New-Object System.Exception( 'A null-value returned from System.String.Replace() while attempting to normalize number decimal separator in input value.' ) );
			}
			#endregion
			
			#region Checking if the input value is correct
			# TODO: Offload to PowerShell engine using ValidatePattern parameter (?)
			if ( -not [RegEx]::IsMatch( $sValueNormalized, "^((\d+\.\d+)|(\d+))(k|m|g)*$" ) ) {
				throw ( New-Object System.Exception( 'Incorrect input value specified.' ) );
			}
			#endregion
			
			if ( [RegEx]::IsMatch( $sValueNormalized, "k|m|g" ) ) { # Converting from (giga/mega/kilo)bytes
				
				if ( $sValueNormalized.IndexOf( 'k' ) -gt 0 ) { # Converting from kilobytes
				
					$sNumericValue = $sValueNormalized.Replace( 'k', '' );
					if ( [System.String]::IsNullOrEmpty( $sNumericValue ) ) {
						throw ( New-Object System.Exception( 'A null-value returned from System.String.Replace() while attempting to remove size specifier letter from input value.' ) );
					}
					$iSizeBytes = ( [Convert]::ToDouble( $sNumericValue, $oFormatProvider ) ) * 1024;
				
				} elseif ( $sValueNormalized.IndexOf( 'm' ) -gt 0 ) { # Converting from megabytes
				
					$sNumericValue = $sValueNormalized.Replace( 'm', '' );
					if ( [System.String]::IsNullOrEmpty( $sNumericValue ) ) {
						throw ( New-Object System.Exception( 'A null-value returned from System.String.Replace() while attempting to remove size specifier letter from input value.' ) );
					}
					$iSizeBytes = ( [Convert]::ToDouble( $sNumericValue, $oFormatProvider ) ) * 1024 * 1024;
					
				} elseif ( $sValueNormalized.IndexOf( 'g' ) -gt 0 ) { # Converting from gigabytes
				
					$sNumericValue = $sValueNormalized.Replace( 'g', '' );
					if ( [System.String]::IsNullOrEmpty( $sNumericValue ) ) {
						throw ( New-Object System.Exception( 'A null-value returned from System.String.Replace() while attempting to remove size specifier letter from input value.' ) );
					}
					$iSizeBytes = ( [Convert]::ToDouble( $sNumericValue, $oFormatProvider ) ) * 1024 * 1024 * 1024
				}
				
			} else { # skip conversion
				$iSizeBytes = ( [Convert]::ToDouble( $sNumericValue, $oFormatProvider ) );
			}
			
			return $iSizeBytes;
			
		} catch { # Processing block
			
			Write-Error `
				-Message "Error occured while attempting to convert value '$Value'. $($_.Exception.Message)" `
				-Exception ( $_.Exception ) `
				-TargetObject ( $Value );
			continue;
		}
	}
	
	end {  }
}