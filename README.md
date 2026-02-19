# While most of Asset Intelligence is still supported, the back-end service for AI categorization is being retired by Microsoft.
Why? Most customers didn't regularly leverage the service...  why was that? You needed to automate the process with a script like this or manually request categorization from time to time. Will they eventually build something like this in Intune? Who knows... but it likely won't require a script or manual action to leverage!
https://learn.microsoft.com/en-us/intune/configmgr/core/clients/manage/asset-intelligence/deprecation

# Start-AICategorization.ps1
Request all uncategorized Inventoried Software in SCCM Asset Intelligence be categorized by the System Center Online service.
https://technet.microsoft.com/en-us/library/gg712316.aspx#BKMK_RequestCatalogUpdate

In order to use this script, you must have already:
 - installed an Asset Intelligence Synchornization Point role (typically on your Primary Site Server if it has internet access, as it is not a client-facing role).
 - enabled the Installed Software class for Hardware Inventory
 - clients that have sent in hardware inventory information that contains Installed Software
 - run the Site Maintenance task "Summarize Installed Software Data" so you will have 'uncategorized' software.
 
 For info on installing the role, enabling the inventory classes, and about the site maintenance task, see:
 https://technet.microsoft.com/en-us/library/gg712322.aspx
 
 
 Nash Pherson
 @KidMystic 
 
