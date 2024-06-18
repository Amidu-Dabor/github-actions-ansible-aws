# Install AWSPowerShell module if not already installed
# Install-Module -Name AWSPowerShell -Force -Verbose

# Import AWSPowerShell module
Import-Module AWSPowerShell

# List EC2 instances
$instances = Get-EC2Instance

# Function to create SSH private key file from GitHub Secrets
function CreateSSHKeyFile {
    param (
        [string]$sshKeySecretName,
        [string]$sshKeyFilePath
    )

    # Fetch SSH key from GitHub Secrets
    $sshPrivateKey = $env:${sshKeySecretName}

    # Write SSH key to file
    Set-Content -Path $sshKeyFilePath -Value $sshPrivateKey
    Set-ItemProperty -Path $sshKeyFilePath -Name IsReadOnly -Value $true
}

# Function to establish SSH connection to an instance
function ConnectToInstance {
    param (
        [string]$publicIpAddress,
        [string]$sshKeyFilePath,
        [string]$ansiblePlaybookPath
    )

    try {
        # Perform SSH connection using the SSH key file
        $sshCommand = "ssh -v -i $sshKeyFilePath -o StrictHostKeyChecking=no ubuntu@$publicIpAddress 'echo \"SSH connection established\"'"
        Invoke-Expression -Command $sshCommand

        # Run Ansible playbook using the SSH key file
        $ansibleCommand = "ansible-playbook --become --inventory my_inventory.aws_ec2.yml --private-key $sshKeyFilePath $ansiblePlaybookPath"
        Invoke-Expression -Command $ansibleCommand
    }
    finally {
        # Clean up the SSH key file
        Remove-Item $sshKeyFilePath
    }
}

# Main script logic
foreach ($instance in $instances) {
    $instanceId = $instance.InstanceId
    $publicIpAddress = $instance.PublicIpAddress
    $sshKeyFilePath = "temp-ssh-key.pem"  # Temporary path for SSH key file

    Write-Output "Instance ID: $instanceId"
    Write-Output "Public IP Address: $publicIpAddress"

    # Check if instance has a public IP address
    if (![string]::IsNullOrEmpty($publicIpAddress)) {
        Write-Output "Connecting to instance: $publicIpAddress"

        # Call function to create SSH key file from GitHub Secrets
        CreateSSHKeyFile -sshKeySecretName "ANSIBLE_SSH_KEY" -sshKeyFilePath $sshKeyFilePath

        # Call function to establish SSH connection and run Ansible playbook
        ConnectToInstance -publicIpAddress $publicIpAddress -sshKeyFilePath $sshKeyFilePath -ansiblePlaybookPath "ansible-playbook.yml"
    } else {
        Write-Output "Instance $instanceId does not have a public IP address."
    }

    Write-Output "------------------------------------------------"
}
