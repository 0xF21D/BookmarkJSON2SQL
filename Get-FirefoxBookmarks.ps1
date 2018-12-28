# ============================
#
# Get-FirefoxBookmarks.ps1
# by Robert Hollingshead
#
# ============================

#Requires -Modules SQLPS

# Location of Bookmark JSON
#$BookmarkPath = 'C:\path\to\your\file.json'
$BookmarkPath = 'C:\Users\Robert\OneDrive\Documents\Scratch\bookmarks-2018-12-20.json'

# Location and name of Microsoft SQL Database
$ServerInstance = 'localhost\SQLExpress'
$Database = 'PowerShell'

# Convenient function to add string escapes if needed.
Function Get-StringWithEscape
{
    Param($String)
    Begin{}
    Process
    {
        # Convert to double apostrophe.
        [string]$EscapedString = $String.replace('''','''''')
    }
    End{
    Return $EscapedString
    }
}

# Function to write to the SQL Database
Function Write-Database
{
    Param($BookmarkList,$ServerInstance,$Database)
    Begin{}
    Process
    {
        Foreach ($Bookmark in $BookmarkList)
        { 
            # Add escape characters to strings.
            [string]$Folder = (Get-StringWithEscape -String $Bookmark.Folder)
            [string]$Title = (Get-StringWithEscape -String $Bookmark.Title)
            [string]$URI = (Get-StringWithEscape -String $Bookmark.URI)
            [string]$RawContent = (Get-StringWithEscape -String $Bookmark.Content)

            # Create query.
            $query = "
                INSERT INTO dbo.FirefoxBookmarks
                VALUES('$($Folder)',
                '$($Title)',
                '$($URI)',
                '$($Bookmark.Status_Code)',
                '$($RawContent)')
            "

            # Attempt to execute query. Write out query to host if fails. Useful for debugging.
            Try { 
            Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query $query -ErrorAction Stop
            }
            catch {
                $query
            }
        }
    }
    End{}
}

# Get bookmarks from converted object. This is a recursive function. 
Function Get-Bookmark 
{
    Param($BookmarkObject,$ContainerTitle)
    Begin{
        [array]$URIList = $null
    }
    Process
    {
        ForEach ($Child in $BookmarkObject.children) 
        {
            switch ($child.typecode) {
                1 # Typecode 1 means this is a URI.
                {
                    $URI = New-Object PSObject
                    $URI | Add-Member -MemberType NoteProperty -Name Folder -Value $($ContainerTitle)
                    $URI | Add-Member -MemberType NoteProperty -Name Title -Value $($Child.Title)
                    $URI | Add-Member -MemberType NoteProperty -Name URI -Value $($Child.URI)

                    Try 
                    { 
                        Write-Verbose -Message "Trying $($Child.URI)"
                        [array]$Site = Invoke-WebRequest -URI $Child.URI
                        $URI | Add-Member -MemberType NoteProperty -Name Status_Code -Value $($Site.StatusCode)
                        $URI | Add-Member -MemberType NoteProperty -Name Content -Value $($Site.RawContent)
                    }
                    Catch
                    {
                        $URI | Add-Member -MemberType NoteProperty -Name Status_Code -Value $($_.Exception.Response.StatusCode.Value__)
                        $URI | Add-Member -MemberType NoteProperty -Name Content -Value ''
                    }
                    
                    
                        $URIList = $URIList + $URI
                }
                2 # Typecode 2 means this is a container of URI.
                {
                    # Call function recursively. 
                    $URIList = $URIList + (Get-Bookmark -BookmarkObject $Child -ContainerTitle $Child.Title)
                }
            }
        }
    }
    End
    {
        return $URIList
    }
}

# Pull in JSON and convert it to PS Object
$BookmarkFile = Get-Content -path $BookmarkPath
$Bookmarks = convertfrom-json -InputObject $BookmarkFile
[array]$BookmarkList = $null

# Set the title of the first container. 
$ContainerTitle = 'Root'

# See if the FirefoxBookmarks table exists by trying to purge it. If it doesn't exist, create it.
try 
{
    Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query "DELETE FROM dbo.FirefoxBookmarks" -ErrorAction Stop | out-null
}
catch
{
    Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query "BEGIN TRANSACTION GO CREATE TABLE dbo.FirefoxBookmarks (Folder nvarchar(MAX) NULL, Title nvarchar(MAX) NULL, URI nvarchar(MAX) NULL, STATUS_CODE nvarchar(10) NULL, CONTENT nvarchar(MAX) NULL) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY] COMMIT BEGIN TRANSACTION GO ALTER TABLE dbo.FirefoxBookmarks SET (LOCK_ESCALATION = TABLE) COMMIT"
}

# Create bookmark list.
$BookmarkList = $BookmarkList + (Get-Bookmark -BookmarkObject $Bookmarks -ContainerTitle $ContainerTitle)

# Write the bookmark list to the database.
Write-Database -BookmarkList $BookmarkList -ServerInstance $ServerInstance -Database $Database