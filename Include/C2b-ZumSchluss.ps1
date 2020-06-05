# dot-source this file to teardown and close an AzureAD session
# that you started with the C2b-AmAnfang.ps1 snippet

try {
    Disconnect-AzureAD -ErrorAction Stop -WhatIf:$false # might raise an error if no existing connection
    Write-Verbose -Message "Disconnected from AzureAD." # will not come here on error
} catch {
    Write-Warning -Message "Disconnect failed, there is no active connection."
    Write-Error -Message $_
} finally {
    # Timestamp
    Write-Verbose -Message "$(Get-Date -Format s) Script finished. ------------------------------------------"
}
