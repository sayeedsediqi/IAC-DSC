Configuration SQL {
    param (
        [string[]]$NodeName,        
        [string]$MachineName,
        [string]$IPAddress,
        [string]$DefaultGateway,
        [string[]]$DNSIPAddress,
        [string]$DomaniName
    )
    
    Import-DscResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module cNetworking
    Import-DscResource -Module xNetworking
    Import-DscResource -Module xComputerManagement
    Import-DscResource -Module xTimeZone
    Import-DscResource -Module xRemoteDesktopAdmin

    Node $AllNodes.Where{$_.Role -eq "SQL"}.Nodename {
        
        xTimeZone SystemTimeZone {
            TimeZone = 'Central Standard Time'
            IsSingleInstance = 'Yes'

        }

        If ((gwmi win32_computersystem).partofdomain -eq $false){
            xComputer NewName {
                Name = $Node.MachineName
                DomainName = $Node.DomainName
                Credential = $Node.Credential
                DependsOn = '[xDNSServerAddress]DnsServerAddress'
            }
        }

        xIPAddress NewIPAddress
        {
            IPAddress      = $Node.IPAddress
            InterfaceAlias = "Ethernet"
            SubnetMask     = 24
            AddressFamily  = "IPV4"
 
        }

        xDefaultGatewayAddress NewDefaultGateway
        {
            AddressFamily = 'IPv4'
            InterfaceAlias = 'Ethernet'
            Address = $Node.DefaultGateway
            DependsOn = '[xIPAddress]NewIpAddress'

        }
        
        xDNSServerAddress DnsServerAddress
        {
            Address        = $Node.DNSIPAddress
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPV4'
        }
        
        xRemoteDesktopAdmin RemoteDesktopSettings {
            Ensure = 'Present'
            UserAuthentication = 'Secure'
        }
        
        xFirewall AllowRDP {
            Name = 'DSC - Remote Desktop Admin Connection'
            Group = 'Remote Desktop'
            Ensure = 'Present'
            Enabled = $true
            Action = 'Allow'
            Profile = 'Domain'
        }        
    }
}

$ConfigData = @{             
    AllNodes = @(             
        @{             
            Nodename = 'ZSQL01'
            MachineName = 'ZSQL01'
            Role = "SQL"
            DomainName = "Zephyr"
            PsDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
            IPAddress = '192.168.2.4'
            DefaultGateway = '192.168.2.1'
            DNSIPAddress = '192.168.2.2'
            Credential = (Get-Credential -UserName 'zephyr\administrator' -message 'Enter admin pwd')
        }                      
    )             
}

SQL -ConfigurationData $ConfigData -OutputPath c:\dsc\sql


$cim = New-CimSession -ComputerName zsql01
$guid=Get-DscLocalConfigurationManager -CimSession $cim| Select-Object -ExpandProperty ConfigurationID


$source = "C:\DSC\sql\ZSQL01.mof"
# Destination is the Share on the SMB pull server
$dest = "DSCService:\Configuration\$guid.mof"
Copy-Item -Path $source -Destination $dest
#Then on Pull server make checksum
New-DSCChecksum $dest

Update-DscConfiguration -CimSession $cim -Wait -Verbose