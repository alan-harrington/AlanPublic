#Alan Harrington Stage vCenter Updates v2.1
#Used to stage the vCenter update, so you don't have to worry about downloading during the maintenance window
#Import the list of vCenter servers and corresponding credential keys from a CSV file.
$vCentersToUpdate = Import-Csv C:\alan\vCentersToUpdate.txt

# Specify the target vCenter version to update to.
$targetVcVersion = "8.0.2.00300"

# Loop through each entry in the CSV file.
foreach ($vc in $vCentersToUpdate) {
    # Retrieve the FQDN of the vCenter from the CSV.
    $vCenter = $vc.vCenterFQDN
    
    # Output the vCenter currently being checked.
    Write-Host "vCenter we are checking is $vCenter"
    
    # Display a message that login is being attempted.
    Write-Host "Login to vCenter" -BackgroundColor Yellow
    
    # Disconnect any existing vCenter Server connections to ensure a clean state.
    Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
    
    # Retrieve the credential key from the CSV and use it to get credentials from the SecretStore.
    $credentialKey = $vc.CredentialKey
    $tempCreds = Get-Secret -Name $credentialKey -Vault 'svc_vCenter_Creds'
    
    # Connect to the specified vCenter server using the credentials retrieved from the SecretStore.
    Connect-VIServer -Server $vCenter -User $tempCreds.Username -Password $tempCreds.GetNetworkCredential().Password
    
    # Fetch available updates and display a message.
    Write-Host "Fetching Available updates" -BackgroundColor Yellow
    $listVcUpdates = Invoke-ListUpdatePending -SourceType "LOCAL_AND_ONLINE"
    
    # Filter the list to find the target version.
    $updateToStage = $listVcUpdates | Where-Object {$_.Version -eq $targetVcVersion} 
    
    # Check if the target version is available and stage it.
    if ($updateToStage) {
        Write-Host "Staging Target Version, please check network and wait 30 mins until checking status" -BackgroundColor Yellow
        Invoke-StageVersionPending -Version $targetVcVersion
    } else {
        Write-Host "Target version $targetVcVersion not found for $vCenter" -BackgroundColor Red
    }
    
    # Clear credentials from memory.
    $tempCreds = $null
    
    # Move on to the next vCenter.
    Write-Host "Onto the next one" -BackgroundColor Yellow
}