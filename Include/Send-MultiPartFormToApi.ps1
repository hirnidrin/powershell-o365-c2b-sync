function Send-MultiPartFormToApi {
<#
.SYNOPSIS
    HTTP POST a "file upload" to an URI.
.DESCRIPTION
    This function assembles a multipart form containing
    - regular single-line string fields
    - blob fields, aka file contents
    and then POSTs the form to an URI.
.PARAMETER $Uri
    The POST URI.
.PARAMETER $FormFields
    A hashtable containing an arbitrary number of "regular" string POST fields/params, eg:
    @{
        'apikey' = 'myapikey';
        'apisecret' = 'mu5tb3b3tt3r';
        'field' = 'learngroup';
        'option' = 'edit';
    }
.PARAMETER $Blobs
    A hashtable containing an arbitrary number of of blob (aka file content) params.
    Each entry in the form body requires 3 values: key, filename, blobdata. Example:
    @{
        'data' = @('data.csv', $mycsvutf8text);
        'pic' =  @('me.png', '...png binary blob data...');
    }
.OUTPUTS
    The PSObject output of the function Invoke-RestMethod.
.EXAMPLE
    Send-MultiPartFormToApi.ps1 `
        -URI 'https://example.com/upload' `
        -FormFields @{ 'secret' = 'lemmein'; 'type' = 'user'; 'action' = 'add'; } `
        -Blobs @{ 'uploadfile' = @('users.csv', $csvlines); }

    Use of common switches
    -Verbose tells you whats going on
    -Debug   shows you the full raw body to be POSTed
    -WhatIf  does not run the POST... use in conjuction with -Verbose -Debug to see what would be POSTed
.LINK
    Credits: @akauppi https://stackoverflow.com/a/25083745/419956
    Credits: @jeroen https://stackoverflow.com/a/41343705/419956
#>
    [CmdletBinding(SupportsShouldProcess = $true)] 
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $Uri,

        [Parameter(Position = 1)]
        [HashTable]
        $FormFields,

        [Parameter(Position = 2)]
        [HashTable]
        $Blobs
    );

    
    # create a boundary guid and start building the form body array
    $boundary = [System.Guid]::NewGuid().ToString()
    Write-Verbose "Setting up body with boundary $boundary"
    $bodyArray = @()

    # add the $FormFields to the form body array
    foreach ($key in $FormFields.Keys) {
        Write-Verbose "... adding field '$key'"
        $bodyArray += "--$boundary"
        $bodyArray += "Content-Disposition: form-data; name=`"$key`""
        $bodyArray += ""
        $bodyArray += $FormFields.Item($key)
    }

    # add the blobs to the form body array
    foreach ($key in $Blobs.Keys) {
        Write-Verbose "... adding blob  '$key'"
        $bodyArray += "--$boundary"
        $bodyArray += "Content-Disposition: form-data; name=`"$key`"; filename=`"$($Blobs.$key[0])`""
        $bodyArray += "Content-Type: application/octet-stream"
        $bodyArray += ""
        $bodyArray += $($Blobs.$key[1])
    }

    # finalize the form body array and convert to text
    $bodyArray += "--$boundary--"
    $nl = "`r`n" # newline
    $bodyText = $bodyArray -join $nl
    # log raw body to debug stream...might be big
    Write-Debug -Message "=== POST body starts at next line    ==="
    Write-Debug -Message $bodyText
    Write-Debug -Message "=== POST body finishes at line above ==="

    # run the HTTP POST
    try {
        if (!$WhatIfPreference) {
            $res = Invoke-RestMethod `
                -Uri $Uri `
                -Method Post `
                -ContentType "multipart/form-data; boundary=`"$boundary`"" `
                -Body $bodyText
            # return the POST result
            Write-Verbose "Successfully POSTed body of length $($bodyText.Length) to $Uri"
            return $res
        } else {
            Write-Verbose "WhatIf is true -> would post body of length $($bodyText.Length) to $Uri"
        }
    } catch {
        Write-Error -Message "Failed to post the form."
        Write-Error -Message $_
        throw
    }
}