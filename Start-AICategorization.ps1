<#
    .SYNOPSIS
        Used to flag all uncategorized software for categorization by the Asset Intelligence service.

    .DESCRIPTION
        Use Start-AICategorization to take all of the Asset Intelligence Inventoried Software that needs to be categorized and mark them for upload to System Center Online for categorization. This script can be used as a scheduled task to send new software periodically for categorization.
    
    .PARAMETER SyncCatalog	
        Optionally tell the AI Sync Point to start a synchronization to send pending categorization requests. Manual synchronizations are only accepted 1 time every 12 hours. The default polling period is 15 minutes, so monitor AIUpdateSvc.log and aikbmgr.log for status.
       
    .PARAMETER Limit
        Optionally specify a naximum number of records to send. If left blank, it will send all uncategorized software up to 9,999 titles.

    .PARAMETER IgnoreString	
        Optionally specify a string to look for in the Product Name to exclude records from synchrization. If the application meta data may include private data, you can use this to not send the records.

    .PARAMETER HideSummary
        Optionally hide the summary information that is displayed at the end.
 
    .EXAMPLE
        Request Asset Intelligence categorization for all uncategorized Inventoried Software:
    
        PS C:\> Start-AICategorization

    .EXAMPLE
        Request Asset Intelligence categorization for up to 100 Inventoried Software records while excluding any software titles that contain "MyDomain":
        
        PS C:\> Start-AICategorization -Limit 100 -IgnoreString "MyDomain"

    .EXAMPLE
        Request Asset Intelligence categorization for up to 500 Inventoried Software records and trigger a synchronization of the AI Sync Point with System Center Online: 
        
        PS C:\> Start-AICategorization -Limit 500 -SyncCatalog

    .NOTES
        Author  : Nash Pherson
        Email   : nashp@nowmicro.com
        Twitter : @KidMysic
        Feedback: Please send feedback!  This is my first real attempt publishing/sharing a powershell script!
        Blog    : http://blog.nowmicro.com/category/nash-pherson/
        Blog    : http://windowsitpro.com/author/nash-pherson
        
    .LINK
        http://gallery.technet.microsoft.com/scirptscenter/ PUT THE GUID HERE
    
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
    [Int]$Limit = 9999,
    [ValidateNotNullOrEmpty()]
    [String]$IgnoreString = "",
    [Switch]$HideSummary = $False
    
)

Begin
{

    $start = Get-Date


    # Find the site code, error out if we are not on the primary...
    Write-Progress -Activity "Requesting Categorization" -Status "Getting the site code" -PercentComplete 0
    $SiteCode = ''

    Get-WMIObject -Namespace "root\SMS" -Class "SMS_ProviderLocation" -ErrorAction SilentlyContinue | foreach-object { if ($_.ProviderForLocalSite -eq $true){$SiteCode=$_.sitecode} }
    If ($SiteCode -eq ''){Throw "Could not determine site code. Ensure you are running this script elevated while on the Primary Site Server. It is not designed to run remotely or without elevation."}

    # Pull the AI summary...
    Write-Progress -Activity "Requesting Categorization" -Status "Gathering summary of AI classification status" -PercentComplete 1
    Write-Verbose "Getting summary of AI classification status before running..."
    $summaryBefore = Invoke-WmiMethod -class SMS_AISoftwarelist -namespace Root\SMS\Site_$($siteCode) -name GetSummary

    # Pull the AI pending list...
    Write-Progress -Activity "Requesting Categorization" -Status "Gathering list of applications from AI that are pending classification" -PercentComplete 2
    Write-Verbose "Getting list of applications from AI that are pending classification..."
    $appsList = Get-WmiObject -Namespace Root\SMS\Site_$($siteCode) -Class SMS_AISoftwarelist -Filter "State = 4"
    Write-Verbose "Unsent categorization requests: $($apps.Count)"


    # Determine if we can send all the pending...
    Write-Verbose "Determine how many records we can send for synchronization..."
    If ($limit -ge 10000) {
        Write-Verbose "The daily limit for sending records is 10,000. Setting the limit for this script to 9,999 or the total number of pending items, whichever is less."
        $limit = 9999
    }
    $max = $limit  # Need logic for setting to total appsList.count or 9999 whichever is lower


    # Send the list for categorization...
    Write-Verbose "Attempting to categorize pending software..."
    $i = 0
    foreach ($app in $appsList) {
        If ($i -lt $max) {

            $i++
            $secondsElapsed = (Get-Date) - $start
            $secondsRemaining = ($secondsElapsed.TotalSeconds / $i) * ($max - $i)

            Write-Progress -Activity "Requesting Categorization" -Status "Sending $i of $max - State $($app.State) - $($app.commonname)" -PercentComplete (($i / $max)*100) -SecondsRemaining $secondsRemaining
            Write-Verbose "Sending $i of $max - State $($app.State) - $($app.commonname) - $($App.SoftwareKey)"

            If ($app.commonname -like "*$($ignoreString)*")
            {
                Write-Warning "Not sending $($app.commonname) because it contains an ignored string: *$($ignoreString)*"
            } 
            ElseIf ($pscmdlet.ShouldProcess('WHATIF Request categorization', $app.commonname)) {
                $request = Invoke-WmiMethod -class SMS_AISoftwarelist -namespace Root\SMS\Site_$($siteCode) -name SetCategorizationRequest -ArgumentList $app.softwarekey
                If ($request.ReturnValue -eq 0) {Write-Verbose "Status $($request.ReturnValue) for $($app.commonname)"} Else {Write-Warning "Return Status $($request.ReturnValue) for $($app.commonname)."}
            }

        } Else {
            # Made it to the max
            Write-Verbose "Synced the maximum number of entries (-Limit, All, or the daily max of 9999)"
            Break    
        }
    }

    # Pull the AI summary after requesting categorization...
    Write-Progress -Activity "Requesting Categorization" -Status "Gathering summary of AI classification status" -PercentComplete 100
    Write-Verbose "Getting summary of AI classification status before running..."
    $summaryAfter = Invoke-WmiMethod -class SMS_AISoftwarelist -namespace Root\SMS\Site_$($siteCode) -name GetSummary
    Write-Progress -Activity "Requesting Categorization" -Completed

    Write-Verbose "Final statistics:"
    # write-Verbose "$($summaryAfter)" FIX THIS

    $secondsElapsed = (Get-Date) - $start
    #$totalTime =  $secondsElapsed.ToString("hh\:mm\:ss")
    $totalTime = $secondsElapsed.ToString("hh\ \h\o\u\r\s\ mm\ \m\i\n\ ss\ \s\e\c")
    write-host "Summary Information"
    write-host "Before: $($SummaryBefore.Uncategorized)"
    write-host "After:  $($SummaryAfter.Uncategorized)"
    write-host "Tried:  $($i)"
    write-host "Got:    $(($SummaryBefore.Uncategorized) - $($SummaryAfter.Uncategorized))"
    write-host "Time Elapsed:  $($totalTime)"
    $appsList = ""


    # Tell the AI Sync Point to synchronize...
    If ($SyncCatalog) {
        Write-Progress -Activity "Requesting Categorization" -Status "Telling AI Sync Point to synchronize at next polling interval." -PercentComplete 100
        Write-Verbose "Flagging AI service to start synchronizing at next cycle. Default polling interval is 900 seconds. Monitor AIUpdateSvc.log and aikbmgr.log for status."
        If ($pscmdlet.ShouldProcess('WHATIF Start sync', $app.commonname)) {Invoke-WmiMethod -class SMS_AIProxy -namespace Root\SMS\Site_$($siteCode) -name RequestCatalogUpdate}
    }
}