#!/bin/bash

# Function to clean up Docker images and containers
cleanup_images() {
    local user=$1
    echo "Cleaning up Docker images and containers for user: $user"
    
    # Switch to the user's environment and perform cleanup
    su -c '
    echo "Stopping all containers for user $USER..."
    docker stop $(docker ps -q) 2>/dev/null
    
    echo "Removing all containers for user $USER..."
    docker rm $(docker ps -a -q) 2>/dev/null
    
    echo "Removing all Docker images for user $USER..."
    docker rmi $(docker images -q) 2>/dev/null
    
    echo "Pruning dangling images, volumes, and build cache for user $USER..."
    docker system prune -f -a 2>/dev/null
    ' - $user
}

# Get a list of users including root
users=$(cut -d: -f1 /etc/passwd)
users="$users root"

# Iterate over each user and prompt for cleanup
for user in $users; do
    # Check if the user exists on the system
    if id "$user" &>/dev/null; then
        read -p "Do you want to clean up Docker images and containers for user $user? (y/n): " choice
        if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
            cleanup_images $user
            echo "Cleanup completed for user $user."
        else
            echo "Skipping cleanup for user $user."
        fi
    fi
done

echo "Cleanup script completed."
