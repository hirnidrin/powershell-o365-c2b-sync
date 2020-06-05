function Tee-Some {
<#
.SYNOPSIS
    Read the merged incoming stream and tee objects that originate from specific streams to a file.
.DESCRIPTION
    This cmdlet is for flexible logging, without need for adding custom log functions within your code.
    Usage (see examples)
    - Just use regular Write-[Error | Warning | Verbose | Debug | Information] commands within your code.
    - If you want to log to a file
      - merge all shell output streams into the output stream by using the operator *>&1
      - pipe it into this cmdlet
      - specify which origin streams to divert to the file, and give the file path
    Remember that the Write-abc cmdlets might produce no output if their preference is set to SilentlyContinue,
    so make sure to set (at least) Continue.
.PARAMETER $Streams
    Array of stream ids that shall be logged to file.
    1 = regular output, 2 = error, 3 = warning, 4 = verbose, 5 = debug, 6 = information
.PARAMETER $Path
    Path + filename of the log file... append mode, file will be created if not existing
.PARAMETER $InputObject
    The object coming thru the pipe. If logging is applicable, $InputObject.ToString() will be logged as message.
.PARAMETER $Csv
    Optional, specifying -Csv will format each output as: "timestamp","streamname","content"
.PARAMETER $PassThru
    Optional, specify -PassThru if you want the input object to passed along the pipe
.EXAMPLE
    MyScript.ps1 *>&1 | Tee-Some -Streams 2,3 -Path MyScript-Err.log -- log warnings and errors to file
    MyScript.ps1 *>&1 | Tee-Some 4,5,6 MyScript.log -- log verbose + debug + information messages
    MyScript.ps1 *>&1 | Tee-Some 2,3 MyScript-Err.log -PassThru -- log warnings and errors to file, and everything to console
    MyScript.ps1 *>&1 | Tee-Some 2,3 MyScript-Err.log -PassThru | Tee-Some 4,5,6 MyScript-Info.log -- log to 2 files
    MyScript.ps1 *>&1 | Tee-Some 2,3 MyScript-Err.log -PassThru | Tee-Some 4,5,6 MyScript-Info.log -PassThru | Tee-Some 1 MyScript.log -- log to 3 files
.LINK
    Question posed by https://stackoverflow.com/questions/30906329
    Solution inspired by https://stackoverflow.com/questions/38523369/write-host-vs-write-information-in-powershell-5/43079024#43079024
#>
    [CmdletBinding()]
    param (
        # What object origin streams to write to the logfile
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateRange(1,6)] 
        [Int[]]$Streams,

        # Path to logfile
        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Path,

        # Captures objects on the output channel... also those redirected from Error, Warning, Verbose, Debug and Information channels
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,

        # Format the logfile as CSV
        [Parameter(Mandatory = $false)]
        [Switch]$Csv,

        # Forward the InputObject down the pipeline
        [Parameter(Mandatory = $false)]
        [Switch]$PassThru
    )
    process {
        # get the input object type, and find out what stream it originated from
        $types = @("ErrorRecord", "WarningRecord", "VerboseRecord", "DebugRecord", "InformationRecord")
        $type = $InputObject.GetType().Name
        $stream = $types.IndexOf($type) + 2 # results in one of: 1 2 3 4 5 6
        if (2 -le $stream) {
            # informational objects that have been redirected to the output stream... cut off the "Record" part
            $streamname = $type.Substring(0, $type.IndexOf("Record"))
        } else {
            # regular objects coming from the output stream
            $streamname = "Output"
        }

        # log if input obj originates from one of the specified streams
        if ($Streams.Contains($stream)) {
            # prepare the log msg as custom object
            $timestamp = (Get-Date).Tostring("yyyy-MM-dd HH:mm:ss.ff")
            $msg = $InputObject.ToString()
            $props = @{
                "Timestamp" = $timestamp;
                "Stream" = $streamname.ToUpper();
                "Message" = $msg
            }
            $log = New-Object -TypeName System.Management.Automation.PSObject -Property $props
            # and write it
            if ($Csv) {
                $log | Select-Object Timestamp, Stream, Message | Export-Csv -Path $Path -Encoding UTF8 -NoTypeInformation -Append
            } else {
                $log.Message | Out-File -FilePath $Path -Encoding UTF8  -Append
            }
        }

        # pass the input object down the pipe if so requested
        if ($PassThru) { Write-Output $InputObject }
      }
}