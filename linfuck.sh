#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to download the hosts file
download_hosts() {
    if command_exists wget; then
        wget -q -O linuxHosts.txt "https://raw.githubusercontent.com/CyberLions/fortnite-the-video-game-parenthesis-the-town-parenthesis/main/hosts/linux.txt"
    elif command_exists curl; then
        curl -s -o linuxHosts.txt "https://raw.githubusercontent.com/CyberLions/fortnite-the-video-game-parenthesis-the-town-parenthesis/main/hosts/linux.txt"
    else
        echo "Error: Neither wget nor curl is installed. Cannot download hosts file."
        exit 1
    fi
}

# Function to deploy the binary
deploy() {
    read -rp "Enter the binary URL: " binary_url
    read -rp "Enter the target directory: " bin_dir
    read -rp "Enter the binary name: " bin_name
    full_path="$bin_dir/$bin_name"

    echo "Deployment Options:"
    echo "1. Deploy binary only"
    echo "2. Deploy binary and create cron job"
    echo "3. Deploy binary and run with nohup"
    echo "4. Deploy binary, run with nohup, and create cron job"
    read -rp "Select deployment option (1-4): " deploy_option

    if [[ "$deploy_option" =~ ^[1-4]$ ]]; then
        :
    else
        echo "Invalid option. Exiting."
        exit 1
    fi

    if [[ "$deploy_option" == "2" || "$deploy_option" == "4" ]]; then
        read -rp "Enter cron job interval in minutes (minimum 1): " cron_interval
        if ! [[ "$cron_interval" =~ ^[0-9]+$ ]] || [ "$cron_interval" -lt 1 ]; then
            echo "Invalid interval. Exiting."
            exit 1
        fi
    fi

    local download_cmd
    if command_exists wget; then
        download_cmd="wget -q -O $full_path $binary_url"
    elif command_exists curl; then
        download_cmd="curl -s -o $full_path $binary_url"
    else
        echo "Error: Neither wget nor curl is available."
        exit 1
    fi

    local commands=("mkdir -p $bin_dir" "$download_cmd" "chmod +x $full_path")
    if [[ "$deploy_option" == "3" || "$deploy_option" == "4" ]]; then
        commands+=("nohup $full_path >/dev/null 2>&1 &")
    fi
    if [[ "$deploy_option" == "2" || "$deploy_option" == "4" ]]; then
        cron_entry="*/$cron_interval * * * * $full_path"
        commands+=("(crontab -l 2>/dev/null; echo '$cron_entry') | crontab -")
    fi

    final_command=$(IFS='; '; echo "${commands[*]}")
    while IFS= read -r host; do
        echo "Deploying to $host..."
        ssh "$host" "$final_command"
        if [ $? -eq 0 ]; then
            echo "Successfully deployed to $host"
        else
            echo "Failed to deploy to $host"
        fi
    done < linuxHosts.txt
}

# Main function
main() {
    # download_hosts
    deploy
}

main
