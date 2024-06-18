# Install AWSPowerShell module if not already installed
# Install-Module -Name AWSPowerShell -Force -Verbose

# Import AWSPowerShell module
Import-Module AWSPowerShell

# Set AWS region
$region = "us-east-1"  # Replace with your desired AWS region

# Initialize AWS credentials (assuming environment variables are set in GitHub Actions)
Initialize-AWSDefaultConfiguration -AccessKey $env:AWS_ACCESS_KEY_ID -SecretKey $env:AWS_SECRET_ACCESS_KEY -Region $region

# List EC2 instances
$instances = Get-EC2Instance

# Loop through each instance
foreach ($instance in $instances) {
    $instanceId = $instance.InstanceId
    $publicIpAddress = $instance.PublicIpAddress
    $privateIpAddress = $instance.PrivateIpAddress

    Write-Output "Instance ID: $instanceId"
    Write-Output "Public IP Address: $publicIpAddress"
    Write-Output "Private IP Address: $privateIpAddress"

    # Retrieve key pair for the instance
    $keyName = $instance.KeyName
    $keyPair = Get-EC2KeyPair -KeyName $keyName

    if ($keyPair -ne $null) {
        # Save the private key material to a temporary file
        $keyMaterial = $keyPair.KeyMaterial
        $tempKeyFile = "C:\path\$keyName.pem"
        $keyMaterial | Out-File -Encoding ascii -FilePath $tempKeyFile

        # Set permissions on the private key file
        Set-ItemProperty -Path $tempKeyFile -Name IsReadOnly -Value $true

        # Perform SSH connection using the private key
        Invoke-SSHCommand -KeyFile $tempKeyFile -Username "ubuntu" -Hostname $publicIpAddress -Command "echo 'SSH connection established'"

        # Clean up the temporary key file
        Remove-Item $tempKeyFile
    } else {
        Write-Output "Key pair '$keyName' not found or inaccessible."
    }

    Write-Output "------------------------------------------------"
}
