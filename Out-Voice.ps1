Function Out-Voice {
    <# 
    .SYNOPSIS 
        Used to allow PowerShell to speak to you or sends data to a WAV file for later listening.
         
    .DESCRIPTION 
        Used to allow PowerShell to speak to you or sends data to a WAV file for later listening.
       
    .PARAMETER InputObject
        Data that will be spoken or sent to a WAV file.

    .PARAMETER Rate
        Sets the speaking rate
   
    .PARAMETER Volume
        Sets the output volume
 
    .PARAMETER ToWavFile
        Append output to a Waveform audio format file in a specified format
   
    .NOTES 
        Name: Out-Voice
        Author: Boe Prox
        DateCreated: 12/4/2013

        To Do: 
            -Support for other installed voices
 
    .EXAMPLE
        "This is a test" | Out-Voice
 
        Description
        -----------
        Speaks the string that was given to the function in the pipeline.
 
    .EXAMPLE
        "Today's date is $((get-date).toshortdatestring())" | Out-Voice
 
        Description
        -----------
        Says todays date
 
     .EXAMPLE
        "Today's date is $((get-date).toshortdatestring())" | Out-Voice -ToWavFile "C:\temp\test.wav"
 
        Description
        -----------
        Says todays date

    #>
 
    [cmdletbinding(
        )]
    Param (
        [parameter(ValueFromPipeline='True')]
        [string[]]$InputObject,
        [parameter()]
        [ValidateRange(-10,10)]
        [Int]$Rate,
        [parameter()]
        [ValidateRange(1,100)]
        $Volume,
        [parameter()]
        [string]$ToWavFile
        )
    Begin {
        $Script:parameter = $PSBoundParameters
        Write-Verbose "Listing parameters being used"
        $PSBoundParameters.GetEnumerator() | ForEach {
            Write-Verbose "$($_)"
        }
        Write-Verbose "Loading assemblies"
        Add-Type -AssemblyName System.speech
        Write-Verbose "Creating Speech object"
        $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
        Write-Verbose "Setting volume"
        If ($PSBoundParameters['Volume']) {
            $speak.Volume = $PSBoundParameters['Volume']
        } Else {
            Write-Verbose "No volume given, using default: 100"
            $speak.Volume = 100
        }
        Write-Verbose "Setting speech rate"
        If ($PSBoundParameters['Rate']) {
            $speak.Rate = $PSBoundParameters['Rate']
        } Else {
            Write-Verbose "No rate given, using default: -2"
            $speak.rate = -2
        }
        If ($PSBoundParameters['WavFile']) {
            Write-Verbose "Saving speech to wavfile: $wavfile"
            $speak.SetOutputToWaveFile($wavfile)
        }
    }
    Process {
        ForEach ($line in $inputobject) {
            Write-Verbose "Speaking: $line"       
            $Speak.SpeakAsync(($line | Out-String)) | Out-Null       
        }
    }
    End {
        If ($PSBoundParameters['ToWavFile']) {
            Write-Verbose "Performing cleanup"
            $speak.dispose()
        }
    }
}