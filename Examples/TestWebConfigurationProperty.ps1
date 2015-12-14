Configuration TestWebConfigurationProperty
{   
    param
    (
        [PSCredential]$ShellCreds,
        [PSCredential]$CertCreds,
        [PSCredential]$FileCopyCreds,
        [string]$NodeFilter = "*"
    )

    Import-DscResource -Module xWebConfigurationProperty

    Node "localhost"
    {
		xWebConfigurationProperty FEVdirUploadReadAheadSize
        {
            PSPath  = "IIS:\Sites\Default Web Site\Microsoft-Server-ActiveSync"         
            Filter = "/system.webServer/serverRuntime"
            Name = "uploadReadAheadSize"
            ValueType = "Int64"
            ValueInt = 16777216
            AllowServiceRestart = $true
        }

		xWebConfigurationProperty BEVdirUploadReadAheadSize
        {
            PSPath  = "IIS:\Sites\Exchange Back End\Microsoft-Server-ActiveSync"         
            Filter = "/system.webServer/serverRuntime"
            Name = "uploadReadAheadSize"
            ValueType = "Int64"
            ValueInt = 16777216
            AllowServiceRestart = $true
        }
    }
}

###Compiles the example
TestWebConfigurationProperty

###Pushes configuration and waits for execution
#Start-DscConfiguration -Path .\TestWebConfigurationProperty -Verbose -Wait