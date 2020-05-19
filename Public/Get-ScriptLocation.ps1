<#
.SYNOPSIS
    Installs a function that gets the location that a script is running from.
.DESCRIPTION
    The .ps1 script creates and calls a function that gets the location that a script is running
    from and returns an object which includes path information for that script. This is useful
    in PowerShell v2 which does not have the built-in variables for:
    
    * $PSScriptRoot
    * $PSScriptCommand
    
    The output also includes two properties which are assumed to be the same for other scripts
    and folders on the file system, so they can be found relative to one or other of these:
    
    * ScriptsDrive  - the drive that the script is saved on
    * ScriptsPath   - the location of the "Scripts" folder under which all scripts are saved
.NOTES
    Filename: Get-ScriptLocation.ps1
    Author:   Charles Joynt
    History:  2015-05-05 Created
.LINK
    http://www.joynt.co.uk/index.php/PowerShell/get-scriptlocation
.EXAMPLE
    [PS]>.\Get-ScriptLocation.ps1
    
    > Returns the Get-Help content for the Get-ScriptLocation function.
.EXAMPLE
    [PS]>.\Get-ScriptLocation.ps1 -Test | Format-List

    PSScriptRoot    : C:\Scripts\PowerShell
    PSScriptCommand : C:\Scripts\PowerShell\Get-ScriptLocation.ps1
    ScriptsDrive    : C:
    ScriptsPath     : C:\Scripts
#>
param(
  [switch]$InstallOnly,
  [switch]$Test
)

if($MyInvocation.CommandOrigin -ne "RunSpace"){
  # This has been called from another script
  $InstallOnly = $true
} else {
  $error.clear()
}

################################################################################################
# Work out the name of the function we are creating from the current file name and check that
# a command (ignoring functions) doesn't already exist with the same name.

$function = $MyInvocation.MyCommand.Name -replace '.ps1',''
$checkcmd = Get-Command | ?{($_.Name -eq $function) -and ($_.CommandType -ne "Function")}

################################################################################################
# Define function
################################################################################################

function GLOBAL:Get-ScriptLocation{
  <#
  .SYNOPSIS
      When run within a script, it returns the location that a script is running from.
  .DESCRIPTION
      When run within a script, it returns the location that a script is running from, including
      the following two properties:
      
      * PSScriptCommand
      * PSScriptRoot
      
  .NOTES
      Function: Get-ScriptLocation
      Author:   Charles Joynt
      History:  2015-05-05 Created
  .LINK
      http://www.joynt.co.uk/index.php/PowerShell/get-scriptlocation
  .EXAMPLE
      <running inside the Get-ScriptLocation.ps1 script>
      
      PSScriptRoot          PSScriptCommand
      ------------          ---------------
      C:\Scripts\PowerShell C:\Scripts\PowerShell\Get-ScriptLocation.ps1
  #>
  
  if($MyInvocation.CommandOrigin -eq "RunSpace"){
    return $null
  } else {
    $PSScriptCommand  = $MyInvocation.ScriptName
    $PSScriptRoot     = Split-Path -Path $MyInvocation.ScriptName -Parent
    $ScriptsDrive     = Split-Path -Path $MyInvocation.ScriptName -Qualifier
    $ScriptsPath      = $PSScriptRoot
    
    # If the PSScriptRoot (path) includes a folder named "Scripts" we work back recursively
    # through $ScriptsPath to remove all child folders from that path.
    
    if($PSScriptRoot -match "\Scripts"){
      $ScriptsPath      = $PSScriptRoot
      while($ScriptsPath -match "\Scripts"){
        $ScriptsPath = Split-Path $ScriptsPath
      }
      $ScriptsPath     += "Scripts"
    }
    
    # Create a custom object with the properties we want to return
    $CustomObject = New-Object -TypeName PSObject -Property @{
      PSScriptCommand = $PSScriptCommand
      PSScriptRoot = $PSScriptRoot
      ScriptsDrive = $ScriptsDrive
      ScriptsPath = $ScriptsPath
    }
    
    # Give this custom object its own TypeName
    $CustomObject.PSObject.TypeNames.Insert(0,'Custom.ScriptLocation')
    
    # Configure and set the default display set
    $defaultDisplaySet = 'PSScriptCommand','PSScriptRoot'
    $defaultDisplayPropertySet = New-Object `
      System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet",[string[]]$defaultDisplaySet)
    
    # Add this display set to the object
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    $CustomObject | Add-Member MemberSet PSStandardMembers $PSStandardMembers
    
    return $CustomObject
  }
}

################################################################################################
# Create a small function that can be used to test the main one

function Test-Function{
  param(
    [string]$function
  )
  Write-Verbose "Testing $function"
  return (& $function)
}

################################################################################################
# Check that the function has been created without errors

if(Get-Command | ?{($_.Name -eq $function) -and ($_.CommandType -eq "Function")}){
  if($error.count -gt 0){
    Write-Warning "Script complete with $($error.count) errors"
    exit 1
  } elseif ($Test){
    & Test-Function -Function $function
  } elseif($InstallOnly){
    exit
  } else {
    Get-Help $function
  }
} else {
  Write-Warning "Global function $function was not created"
  exit 1
}