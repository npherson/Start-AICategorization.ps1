# Start-AICategorization.ps1
Request all uncategorized Inventoried Software identified by SCCM Asset Intelligence be categorized by the System Center Online service.

In order to use this script, you must
 - have already installed an Asset Intelligence Synchornization Point role (typically on your Primary Site Server if it has internet access, as it is not a client-facing role).
 - have enabled the Installed Software class for Hardware Inventory
 - have clients that have sent in hardware invtory information that contains Installed Software
 - and the Site Maintenance task "Summarize Installed Software Data" must have ran so you will have 'uncategorized' software.
 
 For info on installing the role, enabling the inventory classes, and about the site maintenance task, see:
 https://technet.microsoft.com/en-us/library/gg712322.aspx
