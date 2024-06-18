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

# Function to establish SSH connection to an instance
function ConnectToInstance {
    param (
        [string]$publicIpAddress,
        [string]$privateKey,
        [string]$ansiblePlaybookPath
    )

    # Generate a temporary key file
    $tempKeyFile = "temp-ssh-key.pem"
    Set-Content -Path $tempKeyFile -Value $privateKey
    Set-ItemProperty -Path $tempKeyFile -Name IsReadOnly -Value $true

    try {
        # Perform SSH connection using the temporary key file
        $sshCommand = "ssh -i $tempKeyFile -o StrictHostKeyChecking=no ubuntu@$publicIpAddress 'echo \"SSH connection established\"'"
        Invoke-Expression -Command $sshCommand

        # Run Ansible playbook using the temporary key file
        $ansibleCommand = "ansible-playbook --become --inventory my_inventory.aws_ec2.yml --private-key $tempKeyFile $ansiblePlaybookPath"
        Invoke-Expression -Command $ansibleCommand
    }
    finally {
        # Clean up the temporary key file
        Remove-Item $tempKeyFile
    }
}

# Main script logic
foreach ($instance in $instances) {
    $instanceId = $instance.InstanceId
    $publicIpAddress = $instance.PublicIpAddress
    $privateKey = $instance.KeyPair.KeyMaterial  # Assuming KeyMaterial is accessible directly

    Write-Output "Instance ID: $instanceId"
    Write-Output "Public IP Address: $publicIpAddress"

    # Check if instance has a public IP address
    if (![string]::IsNullOrEmpty($publicIpAddress)) {
        Write-Output "Connecting to instance: $publicIpAddress"

        # Call function to establish SSH connection and run Ansible playbook
        ConnectToInstance -publicIpAddress $publicIpAddress -privateKey $privateKey -ansiblePlaybookPath "ansible-playbook.yml"
    } else {
        Write-Output "Instance $instanceId does not have a public IP address."
    }

    Write-Output "------------------------------------------------"
}
