# BookmarkJSON2SQL

Import a Firefox Bookmark JSON to a Microsoft SQL Table.

## Requirements

* PowerShell Core 6.1
* The PowerShell SQLPS module loaded using the WindowsCompatibility module.
* A Microsoft SQL Database
* An exported Firefox Bookmark .JSON file. 

## Usage
This is a very basic script for the time being. For now just in an editor like vscode and change the variables to suit your needs. 

This assumes you know how to create and access a Microsoft SQL Database. 

Pay attention to the following variables:

*In this configuration you would be using the PowerShell database on a locally installed instance of MS SQL Express.

```
# Location of Bookmark JSON
$BookmarkPath = 'C:\path\to\your\file.json'

# Location and name of Microsoft SQL Database
$ServerInstance = 'localhost\SQLExpress'
$Database = 'PowerShell'
```

## Potential Features in the Future

* URI Valication
* Store results of HTTP GET in database.
* Timestamping