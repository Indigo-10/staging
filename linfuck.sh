#!/bin/bash
# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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
        # Fixed cron entry format with all 5 time/date fields
        cron_entry="*/$cron_interval * * * * $full_path"
        commands+=("(crontab -l 2>/dev/null; echo '$cron_entry') | crontab -")
    fi
    
    # Join commands with semicolons, but handle background processes correctly
    final_command=""
    for ((i=0; i<${#commands[@]}; i++)); do
        final_command+="${commands[i]}"
        # Only add semicolon if it's not the last command and the current command doesn't end with &
        if [ $i -lt $(( ${#commands[@]} - 1 )) ]; then
            if [[ "${commands[i]}" != *"&" ]]; then
                final_command+="; "
            else
                final_command+=" "
            fi
        fi
    done
    
    # Authentication options
    read -rp "Enter SSH username: " ssh_user
    
    echo "Authentication Method:"
    echo "1. Password authentication"
    echo "2. SSH key authentication (default key location)"
    echo "3. SSH key authentication (custom key location)"
    read -rp "Select authentication method (1-3): " auth_method
    
    # SSH options
    ssh_opts=""
    
    if [[ "$auth_method" == "1" ]]; then
        # Using sshpass for password authentication
        if ! command_exists sshpass; then
            echo "Warning: sshpass is not installed. Password authentication may not work."
            echo "Consider installing sshpass or using key-based authentication."
        fi
        read -rsp "Enter SSH password: " ssh_pass
        echo ""
    elif [[ "$auth_method" == "3" ]]; then
        read -rp "Enter path to SSH private key: " key_path
        if [ ! -f "$key_path" ]; then
            echo "Error: SSH key file not found. Exiting."
            exit 1
        fi
        ssh_opts="-i $key_path -o StrictHostKeyChecking=no"
    else
        # Default key location
        ssh_opts="-o StrictHostKeyChecking=no"
    fi
    
    # Choose between single IP or IP list file
    echo "Host Selection:"
    echo "1. Single IP address"
    echo "2. IP list file"
    read -rp "Select option (1-2): " host_option
    
    if [[ "$host_option" == "1" ]]; then
        read -rp "Enter IP address: " host_ip
        echo "Deploying to $ssh_user@$host_ip..."
        if [[ "$auth_method" == "1" ]]; then
            sshpass -p "$ssh_pass" ssh -o StrictHostKeyChecking=no "$ssh_user@$host_ip" "$final_command"
        else
            ssh $ssh_opts "$ssh_user@$host_ip" "$final_command"
        fi
        
        if [ $? -eq 0 ]; then
            echo "Successfully deployed to $host_ip"
        else
            echo "Failed to deploy to $host_ip"
        fi
    elif [[ "$host_option" == "2" ]]; then
        read -rp "Enter full path to IP list file: " ip_list_file
        if [ ! -f "$ip_list_file" ]; then
            echo "Error: File not found. Exiting."
            exit 1
        fi
        
        echo "Starting deployment to hosts in $ip_list_file..."
        
        # Read hosts from file into an array for reliable processing
        mapfile -t hosts < "$ip_list_file"
        
        # Iterate through the array
        for host in "${hosts[@]}"; do
            # Skip empty lines and comments
            if [[ -z "$host" || "$host" =~ ^[[:space:]]*# ]]; then
                continue
            fi
            
            # Trim whitespace
            host=$(echo "$host" | tr -d '[:space:]')
            
            echo "Deploying to $ssh_user@$host..."
            if [[ "$auth_method" == "1" ]]; then
                sshpass -p "$ssh_pass" ssh -o StrictHostKeyChecking=no "$ssh_user@$host" "$final_command"
            else
                ssh $ssh_opts "$ssh_user@$host" "$final_command"
            fi
            
            if [ $? -eq 0 ]; then
                echo "Successfully deployed to $host"
            else
                echo "Failed to deploy to $host"
            fi
        done
        
        echo "Deployment completed to all hosts in the list."
    else
        echo "Invalid option. Exiting."
        exit 1
    fi
}

# Main function
main() {
    deploy
}

main
