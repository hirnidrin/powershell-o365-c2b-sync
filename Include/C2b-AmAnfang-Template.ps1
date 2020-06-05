# Config and auth information for the Office 365 -> card2brain sync scripts
#
# 1. create a copy of this file
# 2. rename it to C2b-AmAnfang.ps1
# 3. adapt the following three variable values as required by your infrastructure

# card2brain API auth
$apikey = 'your-c2b-api-key'
$apisecret = 'the-matching-api-secret'

# Office 365 admin user
# the password must be entered manually on first script execution,
# and is then cached in an encrypted text file in the scripts root directory
$adminuser = 'myadmin@mytenant.onmicrosoft.com'

# 4. adapt the Get-RelevantGroups function below
# probably it's enough to just adapt the $CourseRegex param default value
function Get-RelevantGroups {
<#
.SYNOPSIS
    Get the Office 365 group containers that we want to mirror to card2brain.
.DESCRIPTION
    Runs Get-AzureADGroup, filters them by the $CourseRegex param (or default value),
    and returns them as an ArrayList.
.PARAMETER $CourseRegex
    Regex that $group.MailNickName (group email address, without domain) must match
.OUTPUTS ArrayList
    Array of AzureAD groups
.EXAMPLE
    Get-RelevantGroups -CourseRegex '^(ENG|FRA|GER|ITA)(18|19)\.[A-C]{1}$'
#>
    [CmdletBinding()]
    param (
        # Regex that $group.MailNickName must match
        [Parameter(Mandatory = $false)]
        [String]$CourseRegex = '^(ENG|FRA|GER|ITA)(18|19)\.[A-C]{1}|Teachers$'
    )
    process {
        $groups = Get-AzureADGroup -All $true
        $groups = $groups | Where-Object { $_.MailNickName -imatch $CourseRegex } | Sort-Object -Property MailNickName
        Write-Verbose -Message "Retrieved groups from Office 365: $($groups.Count)"
        $groups
    }
}

# 5. adapt the Get-Role function below
function Get-Role {
<#
.SYNOPSIS
    Get the card2brain role that shall be assigned to a given user.
.DESCRIPTION
    Get the card2brain role that shall be assigned to a given user.
.PARAMETER $UserPrincipalName
    The Office 365 login of the user (UPN, including the domain)
.OUTPUTS String
    One of: ROLE_STUDENT ROLE_TEACHER ROLE_ADMIN
.EXAMPLE
    Get-Role -UserPrincipalname 'otto.lamotto@nobrain.ai'
#>
    [CmdletBinding()]
    param (
        # Regex that $group.DisplayName must match
        [Parameter(Mandatory = $true)]
        [String]$UserPrincipalname
    )
    process {
        # determine role within group, depending on UPN structure
        # example:
        # - students UPNs start with the their course, eg: FRA18.B.miller.a@nobrain.ai
        # - all other members of the relevant groups are treated as teachers
        $role = 'ROLE_STUDENT'
        if ($UserPrincipalName -notmatch '^(ENG|FRA|GER|ITA)\d{2}\.[A-C]{1}') {
            $role = 'ROLE_TEACHER'
        }
        # Office 365 admin is also card2brain admin
        if ($UserPrincipalName -ieq $adminuser) {
            $role = 'ROLE_ADMIN'
        }
        $role
    }
}

# Timestamp
Write-Verbose -Message "$(Get-Date -Format s) Script started. -------------------------------------------"

$Script:ErrorActionPreference = "Stop"
$Script:WarningPreference = "Continue"
Write-Verbose -Message "Script:ErrorActionPreference: $Script:ErrorActionPreference"
Write-Verbose -Message "Script:WarningPreference: $Script:WarningPreference"
Write-Verbose -Message "Script:VerbosePreference: $Script:VerbosePreference"
Write-Verbose -Message "Script:DebugPreference: $Script:DebugPreference"
Write-Verbose -Message "Script:InformationPreference: $Script:InformationPreference"

# Load modules, suppress verbose messages for if -verbose is chosen in including script
Import-Module AzureADPreview -Force 4> $null
. ".\Include\Send-MultiPartFormToApi.ps1"

# card2brain api
$apiurl = 'https://card2brain.ch/corporation/bulkUpload'
# local text file where an encrypted copy of the Office 365 admin password is cached, after initial manual login
$passwordfile = "$($adminuser).txt"

# connect to Azure AD
try {
    # if password not (yet) stored in file, ask for password and write to file as secure string
    if (!(Test-Path  -Path $passwordfile)) {
	    Write-Host "Please enter the password for $adminuser and hit the enter key" -Foregroundcolor Yellow
	    Read-Host -AsSecureString | ConvertFrom-SecureString | Out-File $passwordfile -WhatIf:$false
    }
    # read password from file
    $password = Get-Content $passwordfile | ConvertTo-SecureString
    $credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminuser,$password
    # connect... regardless of -WhatIf, we use -WhatIf only in the calling script for actions that would write to somewhere
    $null = Connect-AzureAD -Credential $credentials -WhatIf:$false # suppress success output object
    Write-Verbose "Successfully connected to Azure AD as $adminuser"
} catch {
    Write-Error -Message "Failed to connect to Azure AD."
    Write-Error -Message $_
    throw
}


