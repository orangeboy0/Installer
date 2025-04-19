# Silent Execution
$ErrorActionPreference = "Stop"

# Log file path
$logFile = "$env:APPDATA\TaskbarBuddy\SignTaskbarBuddy.log"

# Create the log directory if it doesn't exist
if (-not (Test-Path (Split-Path $logFile))) {
    New-Item -ItemType Directory -Path (Split-Path $logFile) | Out-Null
}

# Function to log messages
function Log-Message {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] $message"
}

# Function to perform the signing process
function Sign-TaskbarBuddy {
    try {
        Log-Message "Starting signing process."

        # Define paths and variables
        $certName = "TaskbarBuddyCertificate"
        $certPath = "cert:\LocalMachine\My"
        $exportPath = "C:\TaskbarBuddy.pfx"
        $password = "u4N*85iBfU6g^jr"
        $signtoolDir = "C:\Program Files\Taskbar Buddy\SignTool-10.0.22621.6-x86"
        $signtoolPath = "$signtoolDir\signtool.exe"
        $exePath = "C:\Program Files\Taskbar Buddy\Taskbar Buddy.exe"

        # Change directory to SignTool folder
        Set-Location -Path $signtoolDir
        Log-Message "Changed directory to $signtoolDir."

        # Create a self-signed certificate
        Log-Message "Creating self-signed certificate."
        $cert = New-SelfSignedCertificate -DnsName $certName -CertStoreLocation $certPath -Type CodeSigning -NotAfter (Get-Date).AddDays(10000)
        Log-Message "Self-signed certificate created successfully."

        # Export the certificate to PFX format
        Log-Message "Exporting certificate to PFX format."
        $securePassword = ConvertTo-SecureString -String $password -Force -AsPlainText
        Export-PfxCertificate -Cert $cert -FilePath $exportPath -Password $securePassword
        Log-Message "Certificate exported to $exportPath."

        # Import certificate into Trusted Root Certification Authorities
        Log-Message "Importing certificate into Trusted Root Certification Authorities."
        $certFile = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $certFile.Import($exportPath, $password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet)
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
        $store.Open("ReadWrite")
        $store.Add($certFile)
        $store.Close()
        Log-Message "Certificate imported successfully."

        # Sign TaskbarBuddy.exe using SignTool
        Log-Message "Signing TaskbarBuddy.exe using SignTool."
        Start-Process -FilePath $signtoolPath -ArgumentList "sign /f `"$exportPath`" /p `"$password`" /tr `"http://timestamp.sectigo.com`" /td sha256 /fd sha256 /as `"$exePath`"" -Wait -NoNewWindow
        Log-Message "TaskbarBuddy.exe signed successfully."

        Write-Output "Signing completed successfully!"
        Log-Message "Signing process completed successfully."
        exit 0 # Success exit code
    }
    catch {
        $errorMessage = $_.Exception.Message
        Log-Message "Error: $errorMessage"
        Write-Output "Error: $errorMessage"
        exit 1 # Failure exit code
    }
}

# Execute the signing function
Sign-TaskbarBuddy
