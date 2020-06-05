# Mirror relevant Office 365 group containers to card2brain learngroups
# - Run this script every night, after running the regular Office 365 synchs.
# - This only mirrors the group containers, not affecting users / group membership.
# - The script accepts any combination of these command line switches:
#   -Verbose : see basic info what happens
#   -Debug   : show the raw data that is going to be posted to the card2brain API
#   -WhatIf  : read-only simulation, does NOT post any data to the card2brain API
#   To make sure your Office 365 data is retrieved and prepared correctly, first run a simulation:
#   .\C2b-Mirror-Learngroups.ps1 -Verbose -Debug -WhatIf
#   or, logging to a file instead of the console
#   .\C2b-Mirror-Learngroups.ps1 -Verbose -Debug -WhatIf 4>>".\Out\C2b-Mirror-Learngroups.log"
# - For production use, schedule the script and and log to a file, eg:
#   .\C2b-Mirror-Learngroups.ps1 -Verbose 4>>".\Out\C2b-Mirror-Learngroups.log"
#   or with Tee-Some
#   . .\Include\Tee-Some.ps1
#   .\C2b-Mirror-Learngroups.ps1 -Verbose -Debug *>&1 | Tee-Some 2,3 ".\Warn\C2b-Mirror-Learngroups.log" -PassThru | Tee-Some 1,4,5,6 ".\Out\C2b-Mirror-Learngroups.log"

# make the script accept switches: -Verbose -Debug -WhatIf
[CmdletBinding(SupportsShouldProcess = $true)] param()

# make sure -Debug (if present) continues (instead of Inquire or Stop)
# strangely, cannot place this in dot-sourced file... $PSBoundParameters is not available there
if ($PSBoundParameters.ContainsKey("Debug")) {
    $Script:DebugPreference = "Continue"
}

. ".\Include\C2b-AmAnfang.ps1"

# get Office 365 groups that shall be mirrored to card2brain
try {
    $groups = Get-RelevantGroups
} catch {
    Write-Error -Message "Failed to get Office 365 groups."
    Write-Error -Message $_
    . ".\Include\C2b-ZumSchluss.ps1"
    throw
}

# create the c2b learngroups csv text
$dq = '"'    # double quote
$nl = "`r`n" # new line
$csv = ''    # init the csv text
foreach ($group in $groups) {
    # add lines in the format required by the c2b api
    $csv += "$dq$($group.ObjectId)$dq,$dq$($group.DisplayName)$dq,$dq$dq$nl"
}
# make sure it's in UTF8... not required
# see https://stackoverflow.com/a/23257463
#$encoding = [System.Text.Encoding]::UTF8
#$csv = $encoding.GetBytes($csv)

# setup the blob param
$blobs = @{
    'file' = @('learngroup.csv', $csv);
}

# setup the other form params
$formfields = @{
    'apikey' = $apikey;
    'apisecret' = $apisecret;
    'field' = 'learngroup';
    'option' = 'edit';
}

# upload the learngroups to the api
try {
    $response = Send-MultiPartFormToApi -Uri $apiurl -FormFields $formfields -Blobs $blobs #-WhatIf
    Write-Verbose -Message "Response from card2brain API: $response"
} catch {
    Write-Error -Message "Failed to post to card2brain API: learngroup.csv"
    Write-Error -Message $_
    . ".\Include\C2b-ZumSchluss.ps1"
    throw
}

. ".\Include\C2b-ZumSchluss.ps1"
