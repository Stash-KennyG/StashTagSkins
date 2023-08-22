# StashTagSkins
Used to quickly apply and change themes of tags for [Stash](https://github.com/stashapp/stash).

## WARNING
While I will try to support this and fix any basic bugs, <font color="red">**I am not responsible if this nukes your database.  TAKE A BACKUP NOW!  TAKE A BACKUP BEFORE YOUR RUN IT EACH TIME!**</font>  The script does NOT delete any tags.  The only potential data loss is in losing your tag images if they are cleared or overwritten, but please exercise good backup practice.  Find me on discord if you have questions, but do not complain about something this did your stash.  It works for me, and I have tried very hard to make it work, but this is best efforts - not commercial product.

## Prerequisites
This script requires 
 - [PSGraphQL](https://github.com/anthonyg-1/PSGraphQL) and 
 - [Powershell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell).
### Installing Powershell
Powershell runs on Linux, MacOS and Windows.  You do not need to run this script from your stash instance.  For convenience it is configured to look for localhost, but you can select any endpoing.
### Installing PSGraphQL
By Default, you can use the built-in module manager to get PSGraphQL 
```powershell
Install-Module -Name PSGraphQL -Repository PSGallery -Scope CurrentUser
```
## Executing
Open a powershell terminal and execute the main file to connect to a local stash
```powershell
.\StashTagSkins.ps1
```
Or if you'd like you can specify an alternative stash
```powershell
.\StashTagSkins.ps1  -StashAddress "192.168.1.100:9999"
```

### Configuration
Upon launch, the script will ask you questions to select appropriate options.  There are 4 main qustions.
- What library to use?
- Do you want to create new tags that aren't already present?
- Do you want to restore the default tags to images that are not present in your target library
- If you already have a tag image, do you want to overwrite it?

Once you answer these questions, the script will run.
![Output](https://github.com/Stash-KennyG/StashTagSkins/blob/main/HowToResources/Config.png?raw=true)