#!/bin/bash

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define paths to look for the .env file
ENV_FILE_1="$SCRIPT_DIR/../../.env"   # Two levels up
ENV_FILE_2="$SCRIPT_DIR/.env"         # Same directory as the script

# Try to load the .env file from the first path
if [ -f "$ENV_FILE_1" ]; then
    source "$ENV_FILE_1"
    echo "Loaded configuration from $ENV_FILE_1"
elif [ -f "$ENV_FILE_2" ]; then
    source "$ENV_FILE_2"
    echo "Loaded configuration from $ENV_FILE_2"
else
    echo "Error: Configuration file .env not found in $ENV_FILE_1 or $ENV_FILE_2"
    exit 1
fi

# Build the SSH command based on the presence of SSH_PWD or SSH_KEY
if [ -n "$SSH_PWD" ] && [ -z "$SSH_KEY" ]; then
    SSH_CMD="sshpass -p $SSH_PWD ssh"
    SCP_CMD="sshpass -p $SSH_PWD scp"
    echo "Using password-based authentication with sshpass"
elif [ -n "$SSH_KEY" ] && [ -z "$SSH_PWD" ]; then
    SSH_CMD="ssh -i \"$SSH_KEY\""
    SCP_CMD="scp -i \"$SSH_KEY\""
    echo "Using key-based authentication with SSH key"
else
    SSH_CMD="ssh"
    SCP_CMD="scp"
    echo "Using default SSH command"
fi

# Create the tracking file if it doesn't exist
if [ ! -f "$TRACK_FILE" ]; then
    touch "$TRACK_FILE"
fi

# Load all existing hashes into a set for fast lookups
declare -A hash_set
while IFS= read -r line; do
    hash_set["$line"]=1
done < "$TRACK_FILE"

# SSH connection and retrieving the list of files (including files in subdirectories)
remote_files=$($SSH_CMD "$REMOTE_USER@$REMOTE_HOST" "find $REMOTE_PATH -type f \( -name '*.pdf' -o -name '*.doc' -o -name '*.docx' -o -name '*.rtf' -o -name '*.txt' \) | grep -v '/\\.'")

# Download files that haven't been downloaded yet
while IFS= read -r file; do
    # Generate the hash of the file path
    FILE_HASH=$(echo -n "$file" | sha256sum | awk '{print $1}')
    
    # Check if the file hash is already in the set
    if [ -z "${hash_set[$FILE_HASH]}" ]; then
        # Download the file with a .part extension
        TEMP_FILE="$LOCAL_PATH/$(basename "$file").part"
        FINAL_FILE="$LOCAL_PATH/$(basename "$file")"
        
        # Download to a temporary file
        $SCP_CMD "$REMOTE_USER@$REMOTE_HOST:$file" "$TEMP_FILE"
        
        # Ensure the file was downloaded successfully before renaming
        if [ $? -eq 0 ]; then
            echo "Starting to rename file from .part to final version..."
            mv "$TEMP_FILE" "$FINAL_FILE"
            
            # Sync the filesystem to force the write to disk
            sync
            
            if [ $? -eq 0 ]; then
                echo "Renaming succeeded: $FINAL_FILE"
                
                # Add the hash to the set and the tracking file
                echo "$FILE_HASH" >> "$TRACK_FILE"
                hash_set["$FILE_HASH"]=1
            else
                echo "Renaming failed"
            fi
        else
            echo "Failed to download $file"
            rm -f "$TEMP_FILE"  # Remove the incomplete file if the download fails
        fi
    fi
done <<< "$remote_files"

# Check the size of the tracking file and remove older records if necessary
NUM_LINES=$(wc -l < "$TRACK_FILE")

if [ "$NUM_LINES" -gt "$MAX_ENTRIES" ]; then
    # Keep only the last KEEP_ENTRIES records
    tail -n "$KEEP_ENTRIES" "$TRACK_FILE" > "$TRACK_FILE.tmp"
    mv "$TRACK_FILE.tmp" "$TRACK_FILE"
fi

# Remove duplicates and sort the tracking file
sort -u "$TRACK_FILE" -o "$TRACK_FILE"
