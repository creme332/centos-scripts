#!/bin/bash

# Loop through all home directories in /home
for dir in /home/*; do
    if [ -d "$dir" ]; then  # Check if it's a directory
        file="$dir/.dovecot.lda-dupes"
        if [ -f "$file" ]; then  # Check if the file exists
            echo "Deleting: $file"
            rm -f "$file"
        fi
    fi
done

echo "Cleanup complete."
