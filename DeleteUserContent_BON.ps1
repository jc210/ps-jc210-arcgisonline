<# ------------------------------------------------------------------
Script: DeleteUserContent_BON.ps1
Author: John Castillo
Purpose:
Uses the REST interface to remove data from ArcGIS Online and a Portal for ArcGIS server if required.
All actions are logged to a local .html file and also emailed. These settings are in the SendEmail_Exit function.


------------------------------------------------------------------ #>

# ------------------------------------------
param (
    [string]$BonGroup = "learner" # Name of user group.
    )
$GroupTotalMembers = 16 # This is the number of members per user group. Usually, <user>00 - <user>15
$Global:StarDate = get-Date #Saves when script was started. Learn more: http://technet.microsoft.com/en-us/library/ee692801.aspx
$Global:body = @() # To capture our output to variable.
$Global:headers = @{"Accept" = "application/json";"Content-Type" = "application/json"}
$body += '<BODY style="font-family: Calibri; font-size: 11pt;">'
$body += '<b>Script generated email.</b> ' + ($StarDate.DateTime) + '<p>'
# ------------------------------------------




# ArcGIS Online Settings -------------------
$Global:ArcOnlineDomain = 'yourcoolsite.maps.arcgis.com'
$Global:ArcOnlineKey = "_" + "yourcoolsite" # The user name NameID_<url_key_for_org> will be created by ArcGIS Online in its user store.
$Global:arcAdmin = "yourOrgAdminUsername"
$arcCryptoPass = Get-Content -Path .\AGOL-AdminUsername.txt | ConvertTo-SecureString
$arcCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $arcAdmin,$arcCryptoPass
$Global:arcPass = $arcCredentials.GetNetworkCredential().password
#$Global:arcPass = "Password"
# ------------------------------------------

# Portal for ArcGIS Settings ---------------
$Global:portalDomain = 'bon.esri.com'
$Global:portalAdmin = "yourPortalAdminUsername"
$portalCryptoPass = Get-Content -Path .\BON-AdminUsername.txt | ConvertTo-SecureString
$portalCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $portalAdmin,$portalCryptoPass
$portalPass = $portalCredentials.GetNetworkCredential().password
#$Global:portalPass = "Password"
# ------------------------------------------


    

$body += '<b>ArcGIS Online Org: </b><a href="http://' + $ArcOnlineDomain + '" alt=ArcGIS.Server.URL>' + $ArcOnlineDomain + '</a><b> BON Portal: </b><a href="http://' + $portalDomain + '" alt=ArcGIS.Server.URL>' + $portalDomain + '</a><p>'
$body += "<hr>"

Function Generate_Token ($server, $admin, $adminpassword) {
    $body += $body
    $genToken = Invoke-RestMethod -Headers $headers -Uri "https://${server}/sharing/generateToken?f=json&request=gettoken&username=${admin}&password=${adminpassword}&referer=http://www.arcgis.com"
    $genToken.token

#    Write-Host "token: "  $token 
    
IF([string]::IsNullOrWhiteSpace($genToken.token)) {            
    Write-Host "Given string is NULL or having WHITESPACE" 
    $body += "<font color=red>Token generation failed for <b>${server}</b> JSON: " + ($genToken | Out-String) +"</font>"
    SendEmail_Exit $body            
} else {            
   # Write-Host "Given string has a value"
}


    #$genToken = "${AGOLrootURL}/generateToken?f=json&request=gettoken&username=${arcAdmin}&password=${arcPass}&referer=http://www.arcgis.com"
    #$token = Invoke-WebRequest -Uri $genToken  | ConvertFrom-Json | Select -ExpandProperty token
    #Write-Host "HELLO! " + $genToken.psobject.Properties.name # This shows what objects are in the array CONTENT.
}

Function Get_User_Content ($server, $token, $user) {
    $vRootURL = "https://${server}/sharing/rest"
    $vUserURL = "${vRootURL}/content/users"
    $vGroupURL = "${vRootURL}/groups" # http://<community-url>/groups/<groupId>
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
    $vGroupURL = "${vRootURL}/groups" # http://<community-url>/groups/<groupId>
    $vCommunityURL = "${vRootURL}/community/users"    
    
    $JsonCommon = "?token=${token}&f=json"    
    $mylog = @()


    IF($GetUserContent.items.Count -eq 0) {            
        Write-Host "Files is NULL or having WHITESPACE " $server 
        $mylog += $exterminateFiles + "No files found on " + $server + "<br>"           
    } else {            
         Write-Host $exterminateFiles
        $exterminateFiles = $GetUserContent.items.ForEach({Invoke-RestMethod -Headers $headers -Method Post -Uri ($vUserURL + "/" + $user+ "/items/" + $_.id + "/delete" + $JsonCommon)})
        $mylog += $exterminateFiles + "<br>"        
    }
    
    
    IF($GetUserContent.folders.Count -eq 0) {            
        Write-Host "folders is NULL or having WHITESPACE " $server 
        $mylog += $exterminateFolders + "No folders found " + $server + "<br>"           
    } else {            
        Write-Host $exterminateFolders
        $exterminateFolders = $GetUserContent.folders.ForEach({Invoke-RestMethod -Headers $headers -Method Post -Uri ($vUserURL + "/" + $user+ "/" + $_.id + "/delete" + $JsonCommon)})
        $mylog += $exterminateFolders + "<br>"       
    }    

$mylog | Out-String
#
# ------------------------------------------
}

Function SendEmail_Exit ($message) {
$body += $message | Out-String
$body += '<p><center>END OF LINE</center><p></BODY>'

$body = $body | Out-String # Body of email needs to be string.
$myLogFile = ".\log\" + $BonGroup + "-" + $StarDate.ToString("yyyyMMdd-HHmmss") + ".html"
$body | Out-File $myLogFile # Saves as HTML file.

$amiUser = "yourAmazonSESuser"
$amiPass = Get-Content -Path .\AmazonSES-SMTP.txt | ConvertTo-SecureString
$amiCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $amiUser,$amiPass
#$companyUser = "domain\yourUsername" #username for sending emails
#$companyCredentials = new-object -typename System.Management.Automation.PSCredential -argumentlist $esriUser,(Get-Content -Path .\jcastillo-SMTP.txt | ConvertTo-SecureString)

$email = @{
    From = "BON " + $BonGroup + " <you@yourcompany.com>"
    To = "you@yourcompany.com"
    CC = "you@yourcompany.com" 
    Subject = " BON User " + $BonGroup + " cleanup Log"
    #Credential = $companyCredentials
    Credential = $amiCredentials
    SMTPServer = "email-smtp.us-east-1.amazonaws.com"
    Body = $body


    #From = "BON " + $BonGroup + " <you@yourcompany.com>"
    #To = "you@yourcompany.com"
    #CC = "you@yourcompany.com" 
    #Subject = " BON User " + $BonGroup + " cleanup Log"
    #Credential = $companyCredentials
    #Credential = "companyUser"
    #SMTPServer = "smtp.yourcompany.com"
    #Body = $body
}

Send-MailMessage @email -BodyAsHtml -UseSsl
Exit
}

# ArcGIS Online ----------------------------
$Global:ArcOnlineToken = Generate_Token $ArcOnlineDomain $arcAdmin $arcPass
Write-Host "AGOL "$Global:ArcOnlineToken
$body += "<font color=green>Token generated for ${ArcOnlineDomain}</font><br>" 
# ------------------------------------------

# Portal for ArcGIS ------------------------
#$Global:portalDomainToken = Generate_Token ($portalDomain + "/arcgis") $portalAdmin $portalPass
#Write-Host "Portal "$Global:portalDomainToken
#$body += "<font color=green>Token generated for ${portalDomain}</font><br>" 
# ------------------------------------------

For ( $i = 0 ; $i -lt $GroupTotalMembers ; $i++ ) {  # The -lt (Less than) comparison operator is used since PS only counts whole numbers.
    $iBonUser = $BonGroup + $i.ToString("00")

    $iPortals = ($portalDomain + "/arcgis") + " " + $portalDomainToken + " " + $iBonUser
# ------------------------------------------

    Write-Host "Username: " $iBonUser
    

# ArcGIS Online ----------------------------
    $body += "<b>ArcGIS Online: </b>" + $iBonUser + $ArcOnlineKey + "</style><br>"
    $body += Get_User_Content $ArcOnlineDomain $ArcOnlineToken ($iBonUser + $ArcOnlineKey)
    $body += Delete_User_Content $ArcOnlineDomain $ArcOnlineToken ($iBonUser + $ArcOnlineKey)
# ------------------------------------------

# Portal for ArcGIS ------------------------
#    $body += "<b>BON Portal: </b>" + $iBonUser + "</style><br>"   
#    $body += Get_user_Content ($portalDomain + "/arcgis") $portalDomainToken $iBonUser
#    $body += Delete_User_Content ($portalDomain + "/arcgis") $portalDomainToken $iBonUser
#    $body += "<hr>"
# ------------------------------------------


}

SendEmail_Exit $body




Exit # If script runs properly, we actually exit in the SendEmail_Exit function. 
