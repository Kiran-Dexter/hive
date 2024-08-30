#!/bin/bash
if [ $(stat -c "%a" /data/) -ne 755 ]; then
    chmod 755 /data/
    echo "Permissions for /data/ set to 755."
else
    echo "Permissions for /data/ are already 755."
fi

if [ -d /data/podman ]; then
    if [ $(stat -c "%a" /data/podman) -ne 775 ]; then
        chmod -R 775 /data/podman
        echo "Permissions for /data/podman set to 775."
    else
        echo "Permissions for /data/podman are already 775."
    fi
else
    echo "/data/podman directory does not exist."
fi

current_owner=$(stat -c "%U:%G" /data/)
if [ "$current_owner" != "joker:clown" ]; then
    chown -R joker:clown /data/
    echo "Ownership of /data/ set to joker:clown."
else
    echo "Ownership of /data/ is already joker:clown."
fi

