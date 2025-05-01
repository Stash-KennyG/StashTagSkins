#Parameters Go Before Requirements for some reason
#Script assumes local host, but you can use some other location if you need to
param($StashAddress= "localhost:9999")

#Set the GraphAPI endpoint
$graphURI = "http://$stashAddress/graphql"

#Powershell Dependencys for this script
#requires -modules PSGraphQL
#requires -Version 7

#Import Modules know that we know we have them
Import-Module PSGraphQL

#region Setup
#Windows uses weird slashes
$directorySlash = "\"
if (!$IsWindows){
    $directorySlash = "/"
}

#Testing GraphQL
#Query the Stash Instance via GraphQL
$graphQuery = '
query FindTags($filter: FindFilterType, $tag_filter: TagFilterType) {
    findTags(filter: $filter, tag_filter: $tag_filter) {
      count
      tags {
        id
        name
        description
        aliases
        image_path
        __typename
      }
      __typename
    }
  }
 ' 
 $variables = '{
    "filter": {
      "q": "",
      "page": 1,
      "per_page": -1,
      "sort": "name",
      "direction": "ASC"
    }
  }'
$results = $null
try {
    $results = Invoke-GraphQLQuery -Query $graphquery -Uri $graphURI -Variables $variables

}
catch {
    Write-Error "Issue processing GRAPHQL query, your stash is misconfigured or incompatible."
    return
}

#Find the Library Root
$LibraryRoot = "$psscriptpath$($directorySlash)Library"
if (!(test-path "$LibraryRoot"))
{
    $LibraryRoot = ".$($directorySlash)Library"
    if (!(test-path "$LibraryRoot"))
    {
        Write-Host "Please provide the path to the Library Folder"
        Write-Host " ex: c:\StashTagSkins\Library"
        Write-Host " on nix: ~/StashTagSkins/Library"
        $LibraryRoot = Read-Host
        if (!(Test-Path $LibraryRoot))
        {
            Write-Host "File Not Found $library" -ForegroundColor red
            return
        }
    }
}

#List Child Librarys
$children = Get-ChildItem -Directory -path $LibraryRoot
$choice = 0
$index = 1
Write-Host " idx | $("Library Name".padRight(30)) | Tag Count" -ForegroundColor Cyan
foreach ($library in $children)
{
    $tags = Get-ChildItem -Path $library.FullName
    write-host " $($index.toString().padright(3)) | $($library.Name.PadRight(30," ")) | $($tags.count)"
    $index++
}
while (!(($choice -lt $index) -and ($choice -gt 0)))
{
    Write-host "Which Tag Library?"
    $choice = Read-Host
}

#Load the tags in memory so we can search them quickly for matching
$NewTagParsed = [System.Collections.ArrayList]::New()
$newTagFiles = Get-ChildItem -File -path $children[$choice-1].FullName
$counter = 0
foreach ($tagFile in $newTagFiles)
{
    $counter ++
    Write-Progress -Activity "Parsing Tag Json" -Status "$($tagFile.Name) - $counter" -PercentComplete ($counter/($newTagFiles.count)*100)
    $tag = $tagFile | Get-Content | convertFrom-json
    $newTagParsed.Add($tag) | Out-Null
}
Write-Progress -Activity "Parsing Tag Json" -Completed
Write-Host "Loaded $($newTagParsed.count) tags"

#Do we create new tags that don't exist yet?
$AnswerTrue = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', "Creates new tags if we cannot find a matching tag already in the database."
$AnswerFalse = New-Object System.Management.Automation.Host.ChoiceDescription '&No', "Skips tags that aren't yet in the database."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($AnswerTrue, $AnswerFalse)
$title = 'Create new tags'
$message = "Do you want to create new tags that aren't already present?"
$result = $host.ui.PromptForChoice($title, $message, $options, 1)
if ($result -eq 0) {
    $createNewTags = $True
}
elseif ($result -eq 1) {
    $createNewTags = $False
}

#Do we clear the existing images for tags that aren't in the new library?
$AnswerTrue = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', "Clears existing images that are not matched to your new library."
$AnswerFalse = New-Object System.Management.Automation.Host.ChoiceDescription '&No', "Keeps images that exist, but aren't replaced by your new library."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($AnswerTrue, $AnswerFalse)
$title = 'Clear old images'
$message = "Should we clear the image for tags that aren't matched?"
$result = $host.ui.PromptForChoice($title, $message, $options, 1)
if ($result -eq 0) {
    $clearOldTags = $True
}
elseif ($result -eq 1) {
    $clearOldTags = $False
}

#If the new tag match is not blank, overwrite existing images?
$AnswerTrue = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', "Updates tags which match with the new library."
$AnswerFalse = New-Object System.Management.Automation.Host.ChoiceDescription '&No', "If an existing tag is matched but already has an image, nothing will be done."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($AnswerTrue, $AnswerFalse)
$title = 'Overwrite existing images'
$message = "If a tag matches a new library image, but the images are different, do you wish to import the new one?"
$result = $host.ui.PromptForChoice($title, $message, $options, 0)
if ($result -eq 0) {
    $overwriteImages = $True
}
elseif ($result -eq 1) {
    $overwriteImages = $False
}
#endregion

#Region Update Existing Tags
$counter = 0
$LoadedTags = [System.Collections.ArrayList]::new()
#First step is to UPDATE existing tags
#We had a graph result above, let's loop through all the tags
foreach ($tag in $results.data.findTags.tags)
{
    #Report progressInfo
    Write-Debug "Processing $($tag.name)"
    $counter ++
    Write-Progress -Activity "Updating Existing Tags" -Status "Processing $($tag.Name)" -PercentComplete ($counter/($results.data.findTags.tags.count)*100)
    
    #Do we have a matching tag in the database?
    $candidateTag = $NewTagParsed | Where-Object Name -eq $tag.Name
    #look for (new)Name = (existing)Name
    if(!$($candidateTag))
    {
        #Didn't find the tag, let's look for (existing)Name = (new)Alias.
        $candidateTag = $NewTagParsed | Where-Object aliases -contains $tag.Name
        if(!$($candidateTag))
        {
            #Didn't find the tag, let's look for (new)Name = (existing)Alias.
            foreach($TagAlias in $tag.aliases)
            {
                write-debug "  checking $TagAlias"
                $candidateTag = $NewTagParsed | Where-Object name -eq $Tagalias
                if ($candidateTag)
                {
                    write-debug "  found existing alias:$($candidateTag.name)"
                    break
                }
            }
            if (!($candidateTag))
            {
                #Didn't find the tag, last chance let's look for (new) Alias = (existing) alias
                foreach($tagAlias in $tag.aliases)
                {
                    write-debug "  checking $alias"
                    $candidateTag = $NewTagParsed | Where-Object aliases -contains $TagAlias
                    if ($candidateTag)
                    {
                        write-debug "  found new alias match on $($candidateTag.name)"
                        break
                    }
                }
            }
        }
        
    }
    
    #Did we find a tag match?
    if ($candidateTag){
        #set updat to false, and chcek if we are allowed to update it with our config
        $updateImage = $False

        if ($tag.image_path.contains("default=true"))
        {
            #Image is default, we can update it in all cases
            $updateImage = $true
        }
        elseif( $overwriteImages)
        {
            #We have set overwrite Images, good to update
            $updateImage = $true
        }
        if ($updateImage)
        {
            $imagesAreEqual = $false
            try { 
                Write-Debug "Checking NEW: $($candidateTag.Name) vs Existing: $($tag.Name)"
                #Get Existing Image and convert it to base 64
                $image = Invoke-WebRequest -Uri $tag.image_path -Method Get
                # Ensure the content is properly encoded in UTF-8
                #$svgBytes = [System.Text.Encoding]::UTF8.GetBytes($svgContent)
                # Convert the byte array to a base64 string
                #$base64String = [System.Convert]::ToBase64String($svgBytes)
                $image64 = [convert]::ToBase64String(($image.Content))
                $imagesAreEqual = ($candidateTag.image -eq $image64)
            }
            catch {
                Write-Debug "An error while checking existing image, will assume images are not equal: $_"
            }
            

            #See if they are the same
            if (!$imagesAreEqual -and $overwriteImages)
            {
                Write-Debug "Updating..."
                $mutation = 'mutation ($id: ID!, $image: String) {
                    tagUpdate(input: {id: $id, image: $image}) {
                        id
                    }
                    }'
                
                
                $vars = @{
                    id= $($tag.ID)
                    image= "data:image/jpg;base64,$($candidateTag.image)"
                }
                
                
                write-host "Swap image for " -noNewLine
                write-host "$($tag.name)" -NoNewline -ForegroundColor Cyan
                Write-Host " using " -NoNewline
                write-Host "$($candidateTag.name)"  -ForegroundColor cyan
                
                #The Graph Update
                $result = Invoke-GraphQLMutation -Uri $graphURI -Variables $vars -Mutation $mutation
                #Keep track that we have updated this candidate tag
                $LoadedTags.Add($candidateTag) | Out-Null
            } 
            else {
                write-debug "  Image matched for $($candidateTag.Name) - nothing to do"
                $LoadedTags.Add($candidateTag) | Out-Null
            }
        }
        else{
            $LoadedTags.Add($candidateTag) | Out-Null
        }
    }
    else {
        #Do we wish to clear old images?
        if ($clearOldTags)
        {
            Write-host " Clear Image for $($tag.name)" -ForegroundColor Magenta
            Write-Debug "Updating..."
            $mutation = 'mutation ($id: ID!, $image: String) {
                tagUpdate(input: {id: $id, image: $image}) {
                    id
                }
                }'
            
            $vars = @{
                id= $($tag.ID)
                image= ""
            }
            
            
            write-host "Swap image for " -noNewLine
            write-host "$($tag.name)" -NoNewline -ForegroundColor Cyan
            Write-Host " using " -NoNewline
            write-Host "$($candidateTag.name)"  -ForegroundColor cyan
            Invoke-GraphQLMutation -Uri $graphURI -Variables $vars -Mutation $mutation
            $LoadedTags.Add($candidateTag) | Out-Null


        }
    }
}
Write-Progress -Activity "Updating Existing Tags" -Completed
#endregion
            

#Region Status Update
write-host "Updated $($LoadedTags.count) tags" -NoNewline
if ($createNewTags){
    write-host " and $($NewTagParsed.count - $loadedTags.Count) to insert new"
}
else {
    Write-host
}
#endregion

#Region New Tags
if ($createNewTags){
    

    $counter=0
    $tagsChecked = 0
    $errors = 0
    foreach($tag in $NewTagParsed)
    {
        #Walk all of our tags
        $tagsChecked++
        if($LoadedTags.Contains($tag))
        {
            Write-debug "We already have tag '$($tag.name)'"
        }
        else {
            #New Tag, Insert
            $mutation = 'mutation TagCreate($input: TagCreateInput!) {
                tagCreate(input: $input) {
                    id
                }
                }'
            
            $vars = @{input = @{
                name= $tag.name
                aliases = $tag.aliases
                image= "data:image/jpg;base64,$($tag.image)"
                description = $tag.description}
            }

            $counter++
            $result = Invoke-GraphQLMutation -Uri $graphURI -Variables $vars -Mutation $mutation
            #insert statement
            Write-Progress -Activity "Creating Tags" -Status "Creating $($tag.Name)" -PercentComplete ($tagschecked/($newTagParsed.count)*100)
            
            #error handling
            if ($result.errors)
            {
                Write-Host "Error loading $($tag.Name)" -ForegroundColor red
                Write-Host "  $($result.errors.message)" -ForegroundColor Yellow
                write-Host "  Skipping tag and moving to next" -ForegroundColor Yellow
                $errors++
                $counter--
            }
            write-Debug "  Created $($tag.Name) with ID: $($result.data.tagCreate.id)"
        }
    }
    Write-Progress -Activity "Creating Tags" -Completed
    Write-host "Loaded $counter new tags."
    if ($errors)
    {
        write-host " Experienced $errors errors" -ForegroundColor Yellow
    }
}
#endregion