#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# Configuration
IP_FILE="servers.txt"
SSH_USER="${SSH_USER:-root}"       # Uses environment variable $SSH_USER if set, defaults to root
SSH_TIMEOUT=5                      # Connection timeout in seconds

# Check if the IP list file exists
if [[ ! -f "$IP_FILE" ]]; then
    echo "Error: Server list file '$IP_FILE' not found!"
    echo "Please create '$IP_FILE' with one IP address per line."
    exit 1
fi

echo "=================================================="
echo " Starting Server Information Gathering"
echo " Target User: $SSH_USER"
echo "=================================================="

# Loop through each IP/hostname in the file, ignoring empty lines and comments (#)
while IFS= read -r ip || [[ -n "$ip" ]]; do
    # Strip leading/trailing whitespace and skip comments
    ip=$(echo "$ip" | xargs)
    [[ -z "$ip" || "$ip" == \#* ]] && continue

    echo -y
    echo "--------------------------------------------------"
    echo "Querying: $ip"
    echo "--------------------------------------------------"

    # Execute remote commands over SSH with a strict timeout
    if ssh -o ConnectTimeout="$SSH_TIMEOUT" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$SSH_USER@$ip" '
        echo "Hostname:   $(hostname)"
        echo "OS Release: $(grep -oP "^PRETTY_NAME=\K.*" /os-release 2>/dev/null || cat /etc/redhat-release 2>/dev/null || uname -sr)"
        echo "Uptime:     $(uptime -p)"
        echo "--- Memory ---"
        free -h | grep Mem:
        echo "--- Disk Space (/ root) ---"
        df -h / | awk '\''NR==1 || NR==2 {print $0}'\''
    ' 2>&1; then
        echo "[SUCCESS] Finished querying $ip"
    else
        echo "[ERROR] Failed to connect or run commands on $ip"
    fi

done < "$IP_FILE"

echo "=================================================="
echo " Finished gathering server info."
echo "=================================================="