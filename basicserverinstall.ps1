param(
    [Parameter(Position = 0)]
    [string]$defaultGatewayIp = "192.168.1.1",
    [Parameter(Position = 1)]
    [String[]]$dnsServers = ("127.0.0.1", "8.8.8.8"),
    [Parameter(Position = 2)]
    [string]$staticIp = "192.168.1.15",
    [Parameter(Position = 3)]
    [string]$domainname = "domain.local",
    [Parameter(Position = 4)]
    [string]$domainnetbiosname = "newdomain",
    [Parameter(Position = 5)]
    [string]$firefoxUrl = "https://download.mozilla.org/?product=firefox-latest&os=win64&lang=en-US",
    [Parameter(Position = 6)]
    [string]$firefoxInstaller = "C:\Temp\Firefox-Installer.exe"
)

#make directory for the install files
New-Item -Path 'C:\Temp' -ItemType Directory

#setting timezone correct
Set-TimeZone -Id "W. Europe Standard Time"

$ipAddresses = Get-NetIPAddress
$staticIpFound = $ipAddresses | Where-Object { $_.PrefixOrigin -eq 'Manual' }
if ($staticIpFound) {
    Write-Output "Deleting current network config."
    $adapterIndex = (Get-NetAdapter).InterfaceIndex
    Set-NetIPInterface -InterfaceIndex $adapterIndex -Dhcp Enabled
    Set-DnsClientServerAddress -InterfaceIndex $adapterIndex -ResetServerAddresses
} 
else {
    Write-Output "No current network config, creating a new one."
    New-NetIPAddress –IPAddress $staticIp -DefaultGateway $defaultGatewayIp -PrefixLength 24 -InterfaceIndex (Get-NetAdapter).InterfaceIndex -Confirm:$false
    Set-DNSClientServerAddress –InterfaceIndex (Get-NetAdapter).InterfaceIndex –ServerAddresses $dnsServers -Confirm:$false
    Write-Output "Network is succesfully configured."
}

#intalling and configurate ADDS and managementools
$Password = ConvertTo-SecureString -String "Password01" -AsPlainText -Force
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Install-ADDSForest -DomainName $domainname -DomainNetbiosName $domainnetbiosname -ForestMode "default" -DomainMode "default" -InstallDns -NoRebootOnCompletion -SafeModeAdministratorPassword $Password -Confirm:$false

#Install DHCP role with managementtools
Install-WindowsFeature -Name DHCP -IncludeManagementTools
#Authorize DHCP
Add-DhcpServerInDC -DnsName $domainname -IPAddress $staticIp
#Creating DHCP scope
Add-DhcpServerv4Scope -Name "Automation Scope" -StartRange 192.168.1.100 -EndRange 192.168.1.200 -SubnetMask 255.255.255.0
#Remove configuration warning in server manager
Set-ItemProperty –Path registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\ServerManager\Roles\12 –Name ConfigurationState –Value 2

#installing dns role
Install-WindowsFeature -Name DNS -IncludeManagementTools

# Installing firefox
Invoke-WebRequest -Uri $firefoxUrl -OutFile $firefoxInstaller
$installfirefox = (Start-Process -FilePath $firefoxInstaller -ArgumentList "/S" -Wait)
Write-Host "Installation of firefox completed"

#restart everything
Restart-Computer -Force
