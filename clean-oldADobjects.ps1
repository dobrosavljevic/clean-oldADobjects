<#
    A script that looks through an Active Directory for objects (computers and users) and
    disables and moves them to a placeholder OU if they haven't logged into the Active Directory
    for a predetermined amount of time (90 day suggested time frame).

    Further, if the script locates any objects inside the placeholder OUs that are disabled and
    that haven't logged into the Active Directory for longer then a year the script
    should permanently remove the objects from the active directory.

    All of the script's actions should be logged into the domain controller's Event Log.

    Latest Version:
        https://github.com/dobrosavljevic/clean-oldADobjects/blob/master/clean-oldADobjects.ps1

    Usage:
        This script is inteded to be deployed with Ninja RMM to domain controllers and
        automatically executed on a regular schedule.
        
        Alternatively it can be ran manually on servers that support PowerShell script exectuion.

    License: GNU GPL2

    Cpyright Grand Consulting 2022
    Created by Igor Dobrosavljević

    Version History
        2023-02-08 Initial version created
#> 

<#
    0. In this section let's work on the placeholder Organizational Units that will hold the
    unused objects that we are staging for removal.
#>

# Specify and create the OUs for inactive objects if they don't exist.

$Parent_OU              = "OU=Disabled,$((Get-ADDomain).DistinguishedName)"
$Disabled_Computers_OU  = "OU=Computers,$Parent_OU"
$Disabled_Users_OU      = "OU=Users,$Parent_OU"

# Check for existance of top level Disabled OU and create it if it doesn't exist.
if (![bool](Get-ADOrganizationalUnit -Filter 'DistinguishedName -like $Parent_OU')) {
    New-ADOrganizationalUnit -Name "Disabled"
}

# Check for existance of Computers OU and create it if it doesn't exist.
if (![bool](Get-ADOrganizationalUnit -Filter 'DistinguishedName -like $Disabled_Computers_OU')) {
    New-ADOrganizationalUnit -Name "Computers" -Path $Parent_OU
}

# Check for existance of Users OU and create it if it doesn't exist.
if (![bool](Get-ADOrganizationalUnit -Filter 'DistinguishedName -like $Disabled_Users_OU')) {
    New-ADOrganizationalUnit -Name "Users" -Path $Parent_OU
}

<#
    1. Build lists of still enabled computer and user objects that have been inactive for
    at least ninety days.
#>

# Specify the period of inactivity when objects should be considered for deactivation.

$Days_Inactive = 90

# Convert the $Days_Inactive variable to LastLogonTimeStamp property format for the
# -Filter switch to work.

$Time_Inactive = (Get-Date).AddDays(-($Days_Inactive))

# Identify still enabled inactive computer accounts.

$Inactive_Computers = Get-ADComputer -Filter {LastLogonTimeStamp -lt $Time_Inactive -and Enabled -eq $true} -ResultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName, LastLogonDate

# Identify still enabled inactive user accounts.

$Inactive_Users = Get-ADUser -Filter {LastLogonTimeStamp -lt $Time_Inactive -and Enabled -eq $true} -ResultSetSize $null -Properties Name, SamAccountName, DistinguishedName, LastLogonDate

<#
    2. Disable and move still enabled objects that have been inactive into the corresponding
    placeholder OUs.
#>

# Move and disable any inactive computer to the placeholder Organizational Unit
# for disabled computer objects in the domain.

foreach ($Computer in $Inactive_Computers) {
   Disable-ADAccount -Identity $Computer.DistinguishedName
   Move-ADObject -Identity $Computer.DistinguishedName -TargetPath $Disabled_Computers_OU
}

# Move and disable any inactive user to the placeholder Organizational Unit for
# disabled user objects in the domain.

foreach ($User in $Inactive_Users) {
    Disable-ADAccount -Identity $User.DistinguishedName
    Move-ADObject -Identity $User.DistinguishedName -TargetPath $Disabled_Users_OU
 }

<#
    3. Delete any objects that have been inside the placeholder OUs and inactive for at least
    one year.
#>

# Specify the period of inactivity when objects should be considered for removal.

 $Days_Remove = 365

# Convert the $Days_Remove variable to LastLogonTimeStamp property format for the
# -Filter switch to work.

$Time_Remove = (Get-Date).AddDays(-($Days_Remove))

# Enumerate all disabled computer accounts inside the placeholder OUs.

$Disabled_Computers = Get-ADComputer -Filter {LastLogonTimeStamp -lt $Time_Remove -and DistinguishedName -eq 'CN=($Disabled_Computers).Name,$Disabled_Computers_OU'} -ResultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName, LastLogonDate

# Enumerate all disabled computer accoutns inside the placeholder OUs.

$Disabled_Users = Get-ADUser -Filter {LastLogonTimeStamp -lt $Time_Remove -and DistinguishedName -eq 'CN=($Disabled_Users).Name,$Disabled_Users_OU'} -ResultSetSize $null -Properties Name, SamAccountName, DistinguishedName, LastLogonDate