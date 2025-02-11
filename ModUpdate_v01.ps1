<#
.NAME
    ModUpdate

.DESCRIPTION
    - This purpose of this script is to enable any user to update the "mods" folder
    of their game files directory with a pre-determined set of mod files/folders. It does
    this by connecting the end-user's device to an FTP, checking if their "mods" folder
    already contains the files that are on the FTP, and then downloads the files the 
    user does not already have to the end-user's device.

#>

# FTP Connection Variables
$ftpServer = "{FTP_SERVER_IP}"
$ftpUser = "{FTP_USERNAME}"
$ftpPassword = "{FTP_PASSWORD}"
$remotePath = "{FTP_REMOTE_PATH}"
$localUser = ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).Split("\")[1]
$localPath = "C:\Users\$($localUser)\Documents\My Games\FarmingSimulator25\mods\"

Start-Transcript -Path "C:\Users\$($localUser)\ProgramFiles\ModUpdate\Logs\ModUpdate_v01_" + (Get-Date -format "yyyyMMdd-HH:mm:ss.ff") + ".log"


# Dependency flags
$dependencies = $false
$winscpNET = $false
$PSModuleInstalled = $false
$PSModuleImported = $false
$ftpConnect = $false


# Check if WinSCP .NET Assembly is installed
Write-Host "Checking dependencies..." -ForegroundColor Cyan
if (Test-Path -Path "C:\Users\$($localUser)\WinSCP\WinSCP-6.3.6-Automation\WinSCPnet.dll") {
    Write-Host "WinSCP .NET Assembly found. Continuing script..." -ForegroundColor Cyan
    $winscpNET = $true
} else {
    Write-Host "WinSCP .NET Assembly is not installed. Downloading WinSCP .NET Assembly from GitHub repo..." -ForegroundColor Yellow
    
    # Download WinSCP 6.3.6 .NET Assembly
    
    #DownloadFilesFromRepo -Owner "JasonToudt" -Repository "modupdate" -Path "WinSCP-6.3.6-Automation" -DestinationPath "C:\Users\$($localUser)\WinSCP\"
    Invoke-RestMethod "https://github.com/JasonToudt/modupdate/archive/refs/heads/main.zip" -OutFile "C:\Users\$($localUser)\Downloads\modupdate.zip"
    Invoke-WebRequest "https://github.com/JasonToudt/modupdate/archive/refs/heads/main.zip"# -OutFile "C:\Users\$($localUser)\Downloads\modupdate.zip"
    Expand-Archive -Path "C:\Users\$($localUser)\Downloads\modupdate.zip" -DestinationPath "C:\Users\$($localUser)\Downloads\modupdate"
    Copy-Item -Path "C:\Users\$($localUser)\Downloads\modupdate\modupdate-main\WinSCP-6.3.6-Automation\" -Destination "C:\Users\$($localUser)\WinSCP\" -Recurse
    Remove-Item -Path "C:\Users\$($localUser)\Downloads\modupdate.zip", "C:\Users\$($localUser)\Downloads\modupdate" -Force
    
    
    try {
        $url = "https://cdn.winscp.net/files/WinSCP-6.3.6-Automation.zip?secure=YBoBIYOARocZuWtDyOUFLA==,1738877582"
        $downloadZipFile = "C:\Users\$($localUser)\WinSCP\WinSCP-6.3.6-Automation.zip"
        $extractPath = "C:\Users\$($localUser)\WinSCP\WinSCP-6.3.6-Automation"
        # Download the WinSCP .NET assembly zip file
        if (Test-Path -Path "C:\Users\$($localUser)\WinSCP\") {
            Invoke-WebRequest -Uri $url -OutFile $downloadZipFile
        } else {
            New-Item -Path "C:\Users\$($localUser)\WinSCP\" -ItemType Directory
            Invoke-WebRequest -Uri $url -OutFile $downloadZipFile
        }

        # Verify the download
        if (-not (Test-Path -Path $downloadZipFile) -or (Get-Item $downloadZipFile).Length -lt 20000) {
            Write-Error -Message "Failed to download the ZIP file. The file is empty or does not exist." -ErrorAction Stop
        } else {
            Write-Host "WinSCP .NET Assembly downloaded successfully." -ForegroundColor Green
        }

        # Extract the zip file
        if (Test-Path -Path $downloadZipFile) {
            Write-Host "Extracting ZIP archive..." -ForegroundColor Cyan
            Expand-Archive -Path $downloadZipFile -DestinationPath $extractPath -Force
        } else {
            Write-Error -Message "Failed to download the ZIP file. Please check the URL and try again." -ErrorAction Stop
        }

        # Verify extraction
        if (Test-Path -Path "$($extractPath)\WinSCPnet.dll") {
            Write-Host "WinSCP .NET Assembly extracted successfully." -ForegroundColor Green
        } else {
            Write-Error -Message "Failed to extract the ZIP file. Please check the extraction path and try again." -ErrorAction Stop
        }
    }
    catch {
        Write-Error -Message "Error downloading and extracting the .NET Assembly. Please check logs..." -ErrorAction Stop
    }
}

# Check if WinSCP PowerShell module is installed/imported
if (-not (Get-InstalledModule -Name WinSCP -ErrorAction SilentlyContinue)) {
    Write-Host "WinSCP module is not installed. Installing WinSCP module..." -ForegroundColor Yellow
    Install-Module -Name WinSCP -Force
    if (Get-InstalledModule -Name WinSCP) {
        $PSModuleInstalled = $true
    }
} else {
    Write-Host "WinSCP is already installed." -ForegroundColor Cyan
    $PSModuleInstalled = $true
}
if (-not (Get-Module -ListAvailable -Name WinSCP)) {
    Write-Host "WinSCP module is not available. Importing WinSCP module..." -ForegroundColor Yellow
    Import-Module WinSCP
    if (Get-Module -ListAvailable -Name WinSCP) {
        $PSModuleImported = $true
    }
} else {
    Write-Host "WinSCP PowerShell module is already imported." -ForegroundColor Cyan
    $PSModuleImported = $true
}

# Verify that the WinSCP module is truly imported
if ($winscpNET -eq $true -and $PSModuleInstalled -eq $true -and $PSModuleImported -eq $true) {
    Write-Host "Dependencies satisfied. Continuing script..." -ForegroundColor Cyan
    $dependencies = $true
} else {
    Write-Error "Failed to satisfy dependencies. Exiting script..." -ErrorAction Stop
}

# Enter main block
if ($dependencies -eq $true) {
    # Connect to FTP Server
    try {
        # Load WinSCP .NET assembly
        Add-Type -Path "C:\Users\$($localUser)\WinSCP\WinSCP-6.3.6-Automation\WinSCPnet.dll"

        # Setup session options
        $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
            Protocol = [WinSCP.Protocol]::Ftp
            HostName = $ftpServer
            UserName = $ftpUser
            Password = $ftpPassword
        }
        $session = New-Object WinSCP.Session
        try{
            # Connect
            Write-Host 'Connecting to Remote FTP...' -ForegroundColor Magenta
            $session.Open($sessionOptions)
            $ftpConnect = $true
        } 
        catch {
            Write-Host 'Error connecting to FTP Server... Check logs.' -ForegroundColor Red
        }
        <#$files = Get-FtpFileList -remotePath $remotePath
        foreach ($file in $files) {
            $remoteFile = "$($remotePath)/$($file)"
            $localFile = Join-Path $localPath $file#>
    }
    catch {
        Write-Host "There was an error connecting to the FTP. Check logs." -ForegroundColor Yellow
    }
    if ($ftpConnect) {
        Write-Host 'FTP Connection Enabled' -ForegroundColor Green



    }
}


Stop-Transcript