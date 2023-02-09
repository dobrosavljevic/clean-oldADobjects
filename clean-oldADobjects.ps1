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

# Specify the period of inactivity when objects should be considered for deactivation
# and removal.

$Days_Deactivate    = 90
$Days_Remove        = 365

# Specify the placeholder Organizational units for inactive objects.

$Disabled_Computers_OU = "OU=Disabled Computers,$(Get-ADDomain).DistinguishedName"
$Disabled_Users_OU = "OU=Disabled Users,$(Get-ADDomain).DistinguishedName"

# Convert the $Days_Deactivate variable to LastLogonTimeStamp property format for the
# -Filter switch to work.

$Time_Inactive = (Get-Date).AddDays(-($Days_Deactivate))

# Identify inactive computer accounts.

$Inactive_Computers = Get-ADComputer -Filter {LastLogonTimeStamp -lt $Time_Inactive} -ResultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName, LastLogonDate

# Identify inactive user accounts.

$Inactive_Users = Get-ADUser -Filter {LastLogonTimeStamp -lt $Time_Inactive} -ResultSetSize $null -Properties Name, SamAccountName, DistinguishedName, LastLogonDate

# Check for existance of needed Organizational Units in the Active Directory and create
# them if they are not present.

if (-Not(Get-ADOrganizationalUnit -Identity $Disabled_Computers_OU)){
    # New-ADOrganizationalUnit -Name "Disabled Computers" -Path (Get-ADDomain).DistinguishedName
    Write-Host "$Disabled_Computers_OU doesn't exist."
}

if (-Not(Get-ADOrganizationalUnit -Identity $Disabled_Users_OU)) {
    # New-ADOrganizationalUnit -Name "Disabled Users" -Path (Get-ADDomain).DistinguishedName
    Write-Host "$Disabled_Users_OU doesn't exist."
}

# Move and disable any $Inactive_Computers to a placeholder Organizational Unit for
# disabled computer objects in the domain.

foreach ($Computer in $Inactive_Computers){
   # Disable-ADAccount -Identity $Computer.Name
   # Move-ADObject $Computer.DistinguishedName -TargetPath $Disabled_Computers_OU
}

# Move and disable any $Inactive_Users to a placeholder Organizational Unit for
# disabled user objects in the domain.

foreach ($User in $Inactive_Users){
    # Disable-ADAccount -Identity $User.Name
    # Move-ADObject $User.DistinguishedName -TargetPath $Disabled_Users_OU
 }