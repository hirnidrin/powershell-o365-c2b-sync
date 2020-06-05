# Mirror relevant Office 365 users to card2brain.
# - Run this script every night, after running the regular Office 365 synchs.
# - This only mirrors the users, not affecting groups / group membership.
# - The script accepts any combination of these command line switches:
#   -Verbose : see basic info what happens
#   -Debug   : show the raw data that is going to be posted to the card2brain API
#   -WhatIf  : read-only simulation, does NOT post any data to the card2brain API
#   To make sure your Office 365 data is retrieved and prepared correctly, first run a simulation:
#   .\C2b-Mirror-Persons.ps1 -Verbose -Debug -WhatIf
#   or, logging to a file instead of the console
#   .\C2b-Mirror-Persons.ps1 -Verbose -Debug -WhatIf 4>>".\Out\C2b-Mirror-Persons.log"
# - For production use, schedule the script and and log to a file, eg:
#   .\C2b-Mirror-Persons.ps1 -Verbose 4>>".\Out\C2b-Mirror-Persons.log"
#   or with Tee-Some
#   . .\Include\Tee-Some.ps1
#   .\C2b-Mirror-Persons.ps1 -Verbose -Debug *>&1 | Tee-Some 2,3 ".\Warn\C2b-Mirror-Persons.log" -PassThru | Tee-Some 1,4,5,6 ".\Out\C2b-Mirror-Persons.log"

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

# fold members into one list, without duplicates
$members = $groups | Get-AzureADGroupMember -All $true | Sort-Object -Property UserPrincipalName | Get-Unique
# log member count
Write-Verbose -Message "Total members in those groups: $($members.Count)"

# create the members file
$dq = '"'    # double quote
$nl = "`r`n" # new line
$csv = ''    # init the csv text
foreach ($member in $members) {
    # determine general role within card2brain
    $role = Get-Role -UserPrincipalName $member.UserPrincipalName
    # add member as c2b user
    $csv += "$dq$($member.ObjectId)$dq,$dq$($member.UserPrincipalName)$dq,$dq$($member.GivenName)$dq,$dq$($member.Surname)$dq,$dq$($role)$dq$nl"
}
# make sure it's in UTF8... not required
# see https://stackoverflow.com/a/23257463
#$encoding = [System.Text.Encoding]::UTF8
#$csv = $encoding.GetBytes($csv)

# setup the blob param
$blobs = @{
    'file' = @('person.csv', $csv);
}

# setup the other form params
$formfields = @{
    "apikey" = $apikey;
    "apisecret" = $apisecret;
    "field" = "person";
    "option" = "edit";
}

# upload the persons to the api
try {
    $response = Send-MultiPartFormToApi -Uri $apiurl -FormFields $formfields -Blobs $blobs
    Write-Verbose -Message "Response from card2brain API: $response"
} catch {
    Write-Error -Message "Failed to post to card2brain API: person.csv"
    Write-Error -Message $_
    . ".\Include\C2b-ZumSchluss.ps1"
    throw
}

. ".\Include\C2b-ZumSchluss.ps1"
