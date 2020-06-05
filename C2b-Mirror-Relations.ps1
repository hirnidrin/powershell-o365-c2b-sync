# Mirror relevant Office 365 group-to-user membership relations to card2brain.
# - Run this script every night, after running the regular Office 365 synchs.
# - This only mirrors the memberships, not affecting group or user objects themselves.
# - The script accepts any combination of these command line switches:
#   -Verbose : see basic info what happens
#   -Debug   : show the raw data that is going to be posted to the card2brain API
#   -WhatIf  : read-only simulation, does NOT post any data to the card2brain API
#   To make sure your Office 365 data is retrieved and prepared correctly, first run a simulation:
#   .\C2b-Mirror-Relations.ps1 -Verbose -Debug -WhatIf
#   or, logging to a file instead of the console
#   .\C2b-Mirror-Relations.ps1 -Verbose -Debug -WhatIf 4>>".\Out\C2b-Mirror-Relations.log"
# - For production use, schedule the script and and log to a file, eg:
#   .\C2b-Mirror-Relations.ps1 -Verbose 4>>".\Out\C2b-Mirror-Relations.log"
#   or with Tee-Some
#   . .\Include\Tee-Some.ps1
#   .\C2b-Mirror-Relations.ps1 -Verbose -Debug *>&1 | Tee-Some 2,3 ".\Warn\C2b-Mirror-Relations.log" -PassThru | Tee-Some 1,4,5,6 ".\Out\C2b-Mirror-Relations.log"

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

# create the relations file
$dq = '"'    # double quote
$nl = "`r`n" # new line
$csv = ''    # init the csv text
foreach ($group in $groups) {
    $members = $group | Get-AzureADGroupMember -All $true | Sort-Object -Property UserPrincipalName
    Write-Verbose -Message "Members in group $($group.DisplayName): $($members.Count)"
    foreach ($member in $members) {
        # determine role within group
        $role = Get-Role -UserPrincipalName $member.UserPrincipalName
        # add card2brain relation: user / learngroup / role
        $csv += "$dq$($member.ObjectId)$dq,$dq$($group.ObjectId)$dq,$dq$($role)$dq$nl"
    }
}

# setup the blob param
$blobs = @{
    'file' = @('relation.csv', $csv);
}

# setup the other form params
$formfields = @{
    "apikey" = $apikey;
    "apisecret" = $apisecret;
    "field" = "relation";
    "option" = "edit";
}

# upload the relations file to the api
try {
    $response = Send-MultiPartFormToApi -Uri $apiurl -FormFields $formfields -Blobs $blobs
    Write-Verbose -Message "Response from card2brain API: $response"
} catch {
    Write-Error -Message "Failed to post to card2brain API: relation.csv"
    Write-Error -Message $_
    . ".\Include\C2b-ZumSchluss.ps1"
    throw
}

. ".\Include\C2b-ZumSchluss.ps1"
