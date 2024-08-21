#!/bin/bash

# Function to clean up Docker images and containers
cleanup_images() {
    local user=$1
    echo "Cleaning up Docker images and containers for user: $user"
    
    if [ "$user" == "root" ]; then
        echo "Performing cleanup as root..."
        docker stop $(docker ps -q) 2>/dev/null
        docker rm $(docker ps -a -q) 2>/dev/null
        docker rmi $(docker images -q) 2>/dev/null
        docker system prune -f -a 2>/dev/null
    else
        echo "Performing cleanup for user $user..."
        su - "$user" -c '
            docker stop $(docker ps -q) 2>/dev/null
            docker rm $(docker ps -a -q) 2>/dev/null
            docker rmi $(docker images -q) 2>/dev/null
            docker system prune -f -a 2>/dev/null
        '
    fi
}

# Check if the user file is provided and exists
if [ $# -eq 0 ]; then
    echo "Usage: $0 <usernames_file>"
    exit 1
fi

user_file=$1

if [ ! -f "$user_file" ]; then
    echo "The file '$user_file' does not exist."
    exit 1
fi

# Read each username from the file and check if it exists
while IFS= read -r user; do
    echo "Processing user: '$user'"
    user=$(echo "$user" | xargs)  # Trim whitespace
    echo "Trimmed user: '$user'"
    
    if [ -n "$user" ]; then
        if id "$user" &>/dev/null; then
            cleanup_images "$user"
            echo "Cleanup completed for user $user."
        else
            echo "User '$user' does not exist on this system."
        fi
    else
        echo "Skipping empty or invalid user entry."
    fi
done < "$user_file"

echo "Cleanup script completed."

