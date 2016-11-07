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
 
 
 Nash Pherson nashp@nowmicro.com
 @KidMystic
