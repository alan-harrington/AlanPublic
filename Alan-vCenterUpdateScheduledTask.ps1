# Description: This script is used to update multiple vCenter servers to a specified target version. The script reads a list of vCenter servers and corresponding credential keys from a CSV file. It then connects to each vCenter server using the retrieved credentials and checks for available updates. If the target version is found, the script stages the update for installation. The script disconnects from the vCenter server after each operation and clears the credentials from memory to enhance security.
# Alan Harrington Update vCenter Updates v6.1
# Import the list of vCenter servers and corresponding credential keys from a CSV file.
$vCentersToUpdate = Import-Csv C:\alan\vCentersToUpdate.txt

# Specify the target vCenter version to update to.
$targetVcVersion = "8.0.2.00300"

# Iterate through each entry in the CSV file.
foreach ($vc in $vCentersToUpdate) {
    # Retrieve the vCenter FQDN and credential key from the CSV.
    $vCenterFQDN = $vc.vCenterFQDN
    $credentialKey = $vc.CredentialKey
    
    # Retrieve credentials from the specified secret vault.
    $tempCreds = Get-Secret -Name $credentialKey -Vault 'svc_vCenter_Creds'
    
    # Connect to the vCenter server using retrieved credentials.
    Connect-VIServer -Server $vCenterFQDN -User $tempCreds.Username -Password $tempCreds.GetNetworkCredential().Password
    
    # Output the vCenter currently being checked.
    Write-Host "vCenter we are checking is $vCenterFQDN" -BackgroundColor Yellow
    
    # Disconnect any existing vCenter Server connections to ensure a clean state.
    Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
    
    # Taking a snapshot before updates.
    Get-VM "*vc01*" | Sort-Object Name | New-Snapshot -Name "before vCenter update"
    
    # Fetch available updates.
    Write-Host "Fetching Available updates" -BackgroundColor Yellow
    $listVcUpdates = Invoke-ListUpdatePending -SourceType "LOCAL_AND_ONLINE"
    
    # Filter the list to find the target version and stage it if available.
    $updateToStage = $listVcUpdates | Where-Object {$_.Version -eq $targetVcVersion}
    if ($updateToStage) {
        $UpdatePendingInstallRequestBody = Initialize-UpdatePendingStageAndInstallRequestBody -UserData @{ key_example = "Bingo Bango, Let's roll, cross your fingers" }
        Invoke-StageAndInstallVersionPending -Version $targetVcVersion -UpdatePendingStageAndInstallRequestBody $UpdatePendingInstallRequestBody -Confirm:$false
        Write-Host "Update Staged and Installation Initiated for $vCenterFQDN" -BackgroundColor Yellow
    } else {
        Write-Host "Target version $targetVcVersion not found for $vCenterFQDN" -BackgroundColor Red
    }
    
    # Disconnect from the vCenter server.
    Disconnect-VIServer -Server $vCenterFQDN -Confirm:$false -ErrorAction SilentlyContinue
    
    # Clear credentials from memory to enhance security.
    $tempCreds = $null
    
    Write-Host "Onto the next one" -BackgroundColor Yellow
}