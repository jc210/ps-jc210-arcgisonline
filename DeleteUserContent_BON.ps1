<# ------------------------------------------------------------------
Script: DeleteUserContent_BON.ps1
Author: John Castillo
Purpose: Use the ArcGIS REST API to delete user items within your ArcGIS Online organization.
All actions are logged to a local .html file and also emailed. These settings are in the SendEmail_Exit function.
------------------------------------------------------------------ #>

# ------------------------------------------
$TSAccountGroups = @("alpha","beta") # Create list of group accounts
$GroupTotalMembers = 21 # This is the number of members per user group. Naming example: alpha00 - alpha20
$Global:StarDate = get-Date # Saves when script was started. Learn more: http://technet.microsoft.com/en-us/library/ee692801.aspx
$Global:myLogFile = ".\log\" + $BonGroup + "-" + $StarDate.ToString("yyyyMMdd-HHmmss") + ".html" # See Function SendEmail_Exit
$Global:body = @() # Capture our output to this variable
$Global:headers = @{"Content-Type" = "application/x-www-form-urlencoded"}
$body += '<!DOCTYPE html>'
$body += '<BODY style="font-family: Calibri; font-size: 11pt;">'
$body += '<style>#HZ_List ul {margin: 0;padding: 0;} #HZ_List li {list-style-type: none;display: inline;padding: 0 10px;border-left: solid 1px black;} #HZ_List li:first-child {border-left: none;}</style>'
$body += '<b>Script generated email.</b> ' + ($StarDate.DateTime) + '<p>'
# ------------------------------------------

#Esri will require TLS 1.2 connections for ArcGIS Online services starting on April 16, 2019 
#This will force the use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


# ArcGIS Online Settings -------------------
$Global:ArcOnlineDomain = 'yourcoolsite.maps.arcgis.com'
$Global:ArcOnlineKey = "_" + "yourcoolsite" # The user name NameID_<url_key_for_org> will be created by ArcGIS Online in its user store
$Global:arcAdmin = "yourOrgAdminUsername"
$arcCryptoPass = Get-Content -Path .\AGOL-AdminUsername.txt | ConvertTo-SecureString
$arcCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $arcAdmin,$arcCryptoPass
$Global:arcPass = $arcCredentials.GetNetworkCredential().password # Comment this out to use plain text password example below
#$Global:arcPass = "Password"
# ------------------------------------------
    

$body += '<b>ArcGIS Online Org: </b><a href="http://' + $ArcOnlineDomain + '" alt=ArcGIS.Server.URL>' + $ArcOnlineDomain + '</a><p>'
$body += "<hr>"

Function Generate_Token ($server, $admin, $adminpassword) {
    $body += $body
    Write-Host "Using ${server}"
    # Construct our variables used for the token request
    $t_URL = "https://${server}/sharing/rest/generateToken?"
    $t_PostBody = @{"username" = "$admin";"password" = "$adminpassword";"client" = "requestip";"f" = "json"}
    # Send token request and store response as a variable
    $genToken = Invoke-RestMethod -Uri $t_URL -Headers $headers -Method Post -Body $t_PostBody

    $genToken.token

#    Write-Host "token: "  $token 
    
IF([string]::IsNullOrWhiteSpace($genToken.token)) {            
    Write-Host "Given string is NULL or having WHITESPACE" 
    $body += "<font color=red>Token generation failed for <b>${server}</b> JSON: " + ($genToken | Out-String) +"</font>"
    SendEmail_Exit $body
    Exit            
} else {            
    Write-Host "Given string has a value"
}
    #$genToken = "${AGOLrootURL}/generateToken?f=json&request=gettoken&username=${arcAdmin}&password=${arcPass}&referer=http://www.arcgis.com"
    #$token = Invoke-WebRequest -Uri $genToken  | ConvertFrom-Json | Select -ExpandProperty token
    #Write-Host "HELLO! " + $genToken.psobject.Properties.name # This shows what objects are in the array CONTENT.
}

Function Enable_User ($server, $token, $user) {
    $vRootURL = "https://${server}/sharing/rest"
    $vCommunityURL = "${vRootURL}/community/users"    
    
    $JsonCommon = "?token=${token}&f=json"
    $mylog = @()
    
    $EnableUser = Invoke-RestMethod -Headers $headers -Method Post -Uri ($vCommunityURL + "/" + $user + "/enable" + $JsonCommon)
           
    If ($EnableUser.success -eq "true") {
        $mylog += "<font color=#cf33ff style=background-color:GhostWhite;><b>Enable $user account:</b> $EnableUser"  #background GhostWhite
        Write-Host "Is $user account enabled? "$EnableUser -ForegroundColor DarkGreen -BackgroundColor White
        $mylog += " </font><br>" 
    }
    else {
        $mylog += "<font color=white style=background-color:Tomato;><b>Enable $user account error detected:</b> $EnableUser"  #background tomato
        Write-Host "Disable $user account error detected: "$EnableUser -ForegroundColor Red -BackgroundColor White
        $mylog += " </font><br>" 
    }
$mylog | Out-String
}

Function Get_User_Content ($server, $token, $user) {
    $vRootURL = "https://${server}/sharing/rest"
    $vUserURL = "${vRootURL}/content/users"
    $vCommunityURL = "${vRootURL}/community/users"    
    
    $JsonCommon = "?token=${token}&f=json"
    $mylog = @()
    
    $Global:GetUserContent = Invoke-WebRequest -URI ${vUserURL}/${user}${JsonCommon} | ConvertFrom-Json # Items a user owns

    $Global:GetUserDetails = Invoke-WebRequest -URI ${vCommunityURL}/${user}${JsonCommon} | ConvertFrom-Json # Personal details of a user

    #Write-Host $GetUserContent.psobject.Properties.name # This shows what objects are in the array CONTENT.
    #Write-Host $GetUserDetails.psobject.Properties.name # This shows what objects are in the array DETAILS.
    #$GetUserContent.items.id # This displays the items id numbers. We will use this to delete

# ------------------------------------------
# Only displays INFO
    

# Log to memory

 #   $GetUserDetails.groups.ForEach({$mylog += $_.title }) # List group membership
    #$body += "<font color=purple>User created item: TEST</font><br>" # For testing items  
    #$body += "<font color=006600>User created folder: TEST</font><br>" # For testing folders
    
    
    If($GetUserDetails.groups.Count -ne 0) {            
        $mylog += "<font color=FF6600><b>Group member: </b> "
        $GetUserDetails.Groups.ForEach({$mylog += $_.title + "</font><br>"}) # List group membership    
        $GetUserDetails.Groups.ForEach({Write-Host "Member of group: " $_.title -ForegroundColor yellow}) # List group membership
        $mylog += "</font>"           
    } else {            
        #$mylog += "No Groups on $server </font><br>"     
    }
    
    If($GetUserContent.items.Count -ne 0) {            
        $mylog += "<font color=000080><b>User item: </b> "
        $GetUserContent.items.ForEach({$mylog += "<font color=000080>" + $_.id + "</font><br>"}) # List user created items 
        $GetUserContent.items.ForEach({Write-Host "User item: " $_.id -ForegroundColor cyan}) # List user created items  
        $mylog += "</font>"      
    } else {            
        #$mylog += "No items on $server </font><br>"     
    }

    If($GetUserContent.folders.Count -ne 0) {            
        $mylog += "<font color=4AA02C><b>User folder: </b> "
        $GetUserContent.folders.ForEach({$mylog += "<font color=4AA02C>" + $_.id + " Titled:" + $_.title + "</font><br>"}) # List user created folders 
        $GetUserContent.folders.ForEach({Write-Host "User folder: " $_.id -ForegroundColor green}) # List user created folders
        $mylog += "</font>" 
    } else {            
        #$mylog += "No folders on $server </font><br>"     
    }

$mylog | Out-String
#
# ------------------------------------------
}

Function Delete_User_Content ($server, $token, $user) {
    $vRootURL = "https://${server}/sharing/rest"
    $vUserURL = "${vRootURL}/content/users"
    
    $JsonCommon = "?token=${token}&f=json"    
    $mylog = @()

    IF($GetUserContent.items.Count -eq 0) {            
        Write-Host "Files is NULL or having WHITESPACE " $server 
        #$mylog += $exterminateFiles + "No files found on " + $server + "<br>"           
    } else {            
        Write-Host $exterminateFiles
        $removeprotection = $GetUserContent.items.ForEach({Invoke-RestMethod -Headers $headers -Method Post -Uri ($vUserURL + "/" + $user+ "/items/" + $_.id + "/unprotect" + $JsonCommon)})
        $mylog += "Removing delete protections" + $removeprotection + "<br>" 
        $exterminateFiles = $GetUserContent.items.ForEach({Invoke-RestMethod -Headers $headers -Method Post -Uri ($vUserURL + "/" + $user+ "/items/" + $_.id + "/delete" + $JsonCommon)})
        IF ($exterminateFiles -match "error") {
            $mylog += "<font color=red>"
            $mylog += $exterminateFiles + "</font><br>"
            Write-Host "PAINT IT RED"
            }
            else {
            $mylog += $exterminateFiles + "</font><br>"
            Write-Host "PAINT IT BLACK"
            }        
    }
    
    
    IF($GetUserContent.folders.Count -eq 0) {            
        Write-Host "folders is NULL or having WHITESPACE " $server 
        #$mylog += $exterminateFolders + "No folders found " + $server + "<br>"           
    } else {            
        Write-Host $exterminateFolders
        $exterminateFolders = $GetUserContent.folders.ForEach({Invoke-RestMethod -Headers $headers -Method Post -Uri ($vUserURL + "/" + $user+ "/" + $_.id + "/delete" + $JsonCommon)})
        IF ($exterminateFolders -match "error") {
            $mylog += "<font color=red>"
            $mylog += $exterminateFolders + "</font><br>"
            Write-Host "PAINT IT RED"
            }
            else {
            $mylog += $exterminateFolders + "</font><br>"
            Write-Host "PAINT IT BLACK"
            }  
               
    }    

$mylog | Out-String
#
# ------------------------------------------
}

Function SendEmail_Exit ($message) {
$body += $message | Out-String
$body += '<p><center>######  END OF LINE  #####</center><p></BODY>'

$body = $body | Out-String # Body of email needs to be string.
$body | Out-File $myLogFile # Saves as HTML file.

$amiUser = "yourAmazonSESuser"
$amiPass = Get-Content -Path .\AmazonSES-SMTP.txt | ConvertTo-SecureString
$amiCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $amiUser,$amiPass

$email = @{
    From = "BON CleanUp" + "<you@yourcompany.com>"
    To = "user@yourcompany.com"
    CC = "otheruser@yourcompany.com" 
    Subject = " BON User " + $BonGroup + " cleanup Log"
    Credential = $amiCredentials
    SMTPServer = "email-smtp.us-east-1.amazonaws.com"
    Body = $body


}

Write-Host "Trying to send email..."
Send-MailMessage @email -BodyAsHtml -UseSsl -Port 587
Exit
}

Function TSAccountMembers_routine ($BonGroup) {
    $mylog = @()
    For ( $i = 0 ; $i -lt $GroupTotalMembers ; $i++ ) {  # The -lt (Less than) comparison operator is used since PS only counts whole numbers.
        $iBonUser = $BonGroup + $i.ToString("00")
    # ------------------------------------------
    #
        Write-Host "User: " $iBonUser
        
    
    # ArcGIS Online
        $mylog += "<font style=background-color:Snow;><b>User: </b>" + $iBonUser + $ArcOnlineKey + "</font></style><br>"
        $mylog += Disable_User $ArcOnlineDomain $ArcOnlineToken ($iBonUser + $ArcOnlineKey)
        $mylog += Get_User_Content $ArcOnlineDomain $ArcOnlineToken ($iBonUser + $ArcOnlineKey)
        $mylog += Delete_User_Content $ArcOnlineDomain $ArcOnlineToken ($iBonUser + $ArcOnlineKey)
        $mylog += Enable_User $ArcOnlineDomain $ArcOnlineToken ($iBonUser + $ArcOnlineKey)
    
    }
    
    $mylog | Out-String
    }
    


$Global:ArcOnlineToken = Generate_Token $ArcOnlineDomain $arcAdmin $arcPass
Write-Host "AGOL "$Global:ArcOnlineToken
$body += "<font color=green>Token generated for ${ArcOnlineDomain}</font><br>" 

foreach ($group in $TSAccountGroups) {

    $body += TSAccountMembers_routine $group
 
  }

SendEmail_Exit $body


Exit # If script runs properly, we actually exit in the SendEmail_Exit function. 