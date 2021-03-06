<#
    .SYNOPSIS
        Used to flag all unidentified software for categorization by the Asset Intelligence service.

    .DESCRIPTION
        Use Start-AICategorization to take all of the Asset Intelligence Inventoried Software that is 'Uncategorized' (unknown) and request categorization from the Microsoft Intune (System Center Online) service.
        
        You can easily set this script up as a scheduled task on your Primary Site Server using a service account with the SCCM security role of 'Asset Manager'. For example:
        SCHTASKS /Create /TN "ConfigMgr Start-AICategorization" /SC Daily /TR "POWERSHELL.EXE -ExecutionPolicy Bypass -File C:\Scripts\Start-AICategorization.ps1" /RU domain\CM-AI-ServiceAccount /RP *

        See the Request Catalog Update documentation for more details:
        https://technet.microsoft.com/en-us/library/gg712316.aspx#BKMK_RequestCatalogUpdate

    .PARAMETER SyncCatalog	
        Optionally tell the AI Sync Point to start a synchronization to send pending categorization requests. Manual synchronizations are only accepted 1 time every 12 hours. The default polling period is 15 minutes, so monitor AIUpdateSvc.log and aikbmgr.log for status.
       
    .PARAMETER Limit
        Optionally specify a naximum number of records to send. If left blank, it will send all unidentified software up to 9,999 titles.

    .PARAMETER IgnoreProducts	
        Optionally specify one or more strings to look for in the Product Name to exclude records from synchorization. If the application meta data may include private data, you can use this to not send the records.

    .PARAMETER IgnorePublishers
        Optionally specify one or more strings to look for in the Publisher name to exlcude records from synchronization. If the application meta data may include private data, you can use this to not send the records.

    .EXAMPLE
        Request Asset Intelligence categorization for all unidentified Inventoried Software:
    
        PS C:\> Start-AICategorization

    .EXAMPLE
        Request Asset Intelligence categorization for up to 100 Inventoried Software records while excluding any software titles that contain "MyDomain" or "MyCustomApp":
        
        PS C:\> Start-AICategorization -Limit 100 -IgnoreProducts "MyDomain","MyCustomApp","Yahoo Intelligence Email Scanner"

    .EXAMPLE
        Request Asset Intelligence categorization for up to 500 Inventoried Software records and trigger a synchronization of the AI Sync Point with System Center Online: 
        
        PS C:\> Start-AICategorization -Limit 500 -SyncCatalog

    .NOTES
        Author  : Nash Pherson
        Email   : nashp@nowmicro.com
        Twitter : @KidMytsic  https://twitter.com/kidmystic
        Feedback: Please send feedback! This is my first real attempt publishing/sharing a powershell tool!
        Blog    : http://blog.nowmicro.com/category/nash-pherson/
        Blog    : http://windowsitpro.com/author/nash-pherson
        Tools   : http://nowmicro.com/RCT
        
    .LINK
        https://gallery.technet.microsoft.com/ConfigMgr-Request-d167ff3c
    
    .LINK
        http://www.nowmicro.com
#>

##Requires -RunAsAdministrator

[CmdletBinding(
    SupportsShouldProcess=$True
)]

Param
(
    [Switch]$SyncCatalog = $False,
    [ValidateNotNullOrEmpty()]
    [ValidateRange(1,9999)]
    [Int]$Limit=50000,
    [String[]]$IgnoreProducts = @(''),
    [String[]]$IgnorePublishers = @('')   
)

Begin
{
    $start = Get-Date

    # Find the site code from the SMS Provider...
    Write-Progress -Activity 'Requesting Categorization' -Status 'Getting the site code' -PercentComplete 0
    $SiteCode = ''
    Get-WMIObject -Namespace 'root\SMS' -Class 'SMS_ProviderLocation' -ErrorAction SilentlyContinue |
        foreach-object{
            if ($_.ProviderForLocalSite -eq $true)
            {
                $SiteCode=$_.sitecode
            } 
        } 


    # Error out if we couldn't find the Primary\SMS Provider...
    If([String]::IsNullOrEmpty($SiteCode))
    {
        Throw 'Could not determine site code. Ensure you are running this script elevated while on the Primary Site Server \ SMS Provider. It is not designed to run remotely or without elevation.'
    }


    #Error out if we couldn't find an AI Sync Point...
    Write-Progress -Activity 'Requesting Categorization' -Status 'Verifying at least one site system has the AI Sync Point role' -PercentComplete 0
    $aiSyncPoint = Get-WMIObject -Class SMS_SystemResourceList -NameSpace root\sms\site_$SiteCode -Filter 'RoleName = "AI Update Service Point"'
    If([String]::IsNullOrEmpty($aiSyncPoint))
    {
        Throw 'Could not locate an Asset Intelligence Synchronization Point role on any site system. Please ensure you have installed the AI Sync Point role on a site system with internet access.'
    }
    

    # Pull the AI summary...
    Write-Progress -Activity 'Requesting Categorization' -Status 'Gathering summary of AI classification status' -PercentComplete 1
    Write-Verbose -Message 'Getting summary of AI classification status before running...'
    $summaryBefore = Invoke-WmiMethod -class SMS_AISoftwarelist -namespace Root\SMS\Site_$($siteCode) -name GetSummary -WhatIf:$false

    # Pull the AI pending list...
    Write-Progress -Activity 'Requesting Categorization' -Status 'Gathering list of applications from AI that are pending classification' -PercentComplete 2
    Write-Verbose -Message 'Getting list of applications from AI that are pending classification...'
    [array]$appsList = Get-WmiObject -Namespace Root\SMS\Site_$($siteCode) -Class SMS_AISoftwarelist -Filter 'State = 4'
    Write-Verbose -Message "Uncategorized applications according to summarized AI data: $($appsList.Count)"
    

    
    # Commenting out the arbitrary 10k record limit... Once upon a time the daily limit for sending records was 10,000.
    # This was because the Microsoft Online Service was hosted on a desktop computer beneath someone's desk... And that
    # person didn't work there anymore... and nobody really knew where that computer was... or why it kept crashing when
    # people sent too many records.  But that's fixed now... so that's good. #ThereIsNoCloud    
    
    # Determine if we can send all the pending or if we need to limit it...
    #Write-Verbose -Message 'Determine how many records we can send for synchronization...'
    #If ($limit -ge 10000)
    #{
        #Write-Warning -Message 'Setting the limit for this script to 9,999 or the total number of pending items, whichever is less.'
        #$limit = 9999
    #}


    # Set the maximum number to send... either all or the limit parameter.
    If ($appsList.Count -lt $Limit) 
    {
        $max = $appsLIst.Count
    } Else {
        $max = $limit
    }

    
    Write-Verbose -Message "Maximum number of software to attempt requesting categoriztaion: $($max)"

    # Send the list for categorization...
    Write-Verbose -Message 'Attempting to mark unidentified software for requesting categorization...'
    $i = 0
    foreach ($app in $appsList)
    {

        # Check to see if we can keep going or if we've hit our maximum number of items...
        If($i -ge $max)
        {
                Write-Verbose -Message "Attempted the maximum number of entries (-Limit, All, or the daily max of 9999): $($Max)"
                Break
        } Else {
                 $i++
                $secondsElapsed = (Get-Date) - $start
                $secondsRemaining = ($secondsElapsed.TotalSeconds / $i) * ($max - $i)
        }


        $skip = $False
        # Check for ignored Product Name...
        Foreach ($prodName in $IgnoreProducts)
        {
            If ($prodName -ne '' -And $app.CommonName -Like "*$($prodName)*")
            {
                $skip=$True
                Write-Warning -Message "Not sending `"$($app.CommonName)`" because the Product contains an ignored string: *$($prodName)*"
            }
        }
        
            
        # Check for ignored Publisher...
        Foreach ($pubName in $IgnorePublishers)
        {
            If ($pubName -ne '' -And $app.CommonPublisher -Like "*$($pubName)*")
            {
                $skip=$True
                Write-Warning -Message "Not sending `"$($app.CommonName)`" from `"$($app.CommonPublisher)`" because the Publisher contains an ignored string: *$($pubName)*"
            }
        }

        # Stop this iteration of the loop if we found an ignoreProducts or ignorePublishers match...
        If ($skip -eq $True)
        {
            Continue
        }
        
        # Finally... let's try to send some software for categorization!
        If ($pscmdlet.ShouldProcess(($app.CommonName), 'Request categorization'))
        {
            Write-Progress -Activity 'Requesting Categorization' -Status "Sending $i/$max - State $($app.State) - $($app.CommonName)" -PercentComplete (($i / $max)*100) -SecondsRemaining $secondsRemaining
            Write-Verbose -Message "Sending $i/$max - State $($app.State) - $($app.CommonName) - $($App.SoftwareKey)"
                
            # Set the software categorization request...
            $request = Invoke-WmiMethod -class SMS_AISoftwarelist -namespace Root\SMS\Site_$($siteCode) -name SetCategorizationRequest -ArgumentList $app.softwarekey
                
            # Output the status if successful and a warning if it fails...
            If ($request.ReturnValue -eq 0)
            {
                Write-Verbose -Message "Status $($request.ReturnValue) for $($app.CommonName)"
            } Else {
                Write-Warning -Message "Return Status $($request.ReturnValue) for $($app.CommonName)."
            }
        }

    }


    # Tell the AI Sync Point to synchronize if requested...
    If ($SyncCatalog)
    {
        Write-Progress -Activity 'Requesting Categorization' -Status 'Telling AI Sync Point to synchronize at next polling interval.' -PercentComplete 100
        Write-Verbose -Message 'Flagging AI service to start synchronizing at next cycle. Default polling interval is 900 seconds. Monitor AIUpdateSvc.log and aikbmgr.log for status.'
        If ($pscmdlet.ShouldProcess('Start sync', 'AI Catalog')) {$SyncOutput = Invoke-WmiMethod -class SMS_AIProxy -namespace Root\SMS\Site_$($siteCode) -name RequestCatalogUpdate}
    }


    # Pull the AI summary after requesting categorization...
    Write-Progress -Activity 'Requesting Categorization' -Status 'Gathering summary of AI classification status' -PercentComplete 100
    Write-Verbose -Message 'Getting summary of AI classification status after running...'
    $summaryAfter = Invoke-WmiMethod -class SMS_AISoftwarelist -namespace Root\SMS\Site_$($siteCode) -name GetSummary -WhatIf:$false
    Write-Progress -Activity 'Requesting Categorization' -Completed

    # Output the final script summary... 
    $secondsElapsed = (Get-Date) - $start
    $totalTime = $secondsElapsed.ToString('hh\ \h\o\u\r\s\ mm\ \m\i\n\ ss\ \s\e\c')
    $properties = @{'UncategorizedBefore'=$($SummaryBefore.Uncategorized);
                'UncategorizedAfter'=$($SummaryAfter.Uncategorized);
                'Attempted'=$i;
                'Completed'=$(($SummaryBefore.Uncategorized) - $($SummaryAfter.Uncategorized));
                'TimeElapsed'=$($totalTime)}
    $outputObject = New-Object -TypeName PSObject -Property $properties
    Write-Output $outputObject
}
