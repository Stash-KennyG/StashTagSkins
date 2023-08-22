# StashTagSkins
Used to quickly apply and change themes of tags for [Stash](https://github.com/stashapp/stash).

## Prerequisites
This script requires [PSGraphQL](https://github.com/anthonyg-1/PSGraphQL) and [Powershell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell).
### Installing Powershell
Powershell runs on Linux, MacOS and Windows.  You do not need to run this script from your stash instance.  For convenience it is configured to look for localhost, but you can select any endpoing.
### Installing PSGraphQL
By Default, you can use the built-in module manager to get PSGraphQL 
```powershell
Install-Module -Name PSGraphQL -Repository PSGallery -Scope CurrentUser
```