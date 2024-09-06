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
    
# If not found, try the second path
elif [ -f "$ENV_FILE_2" ]; then
    source "$ENV_FILE_2"
    echo "Loaded configuration from $ENV_FILE_2"
    
# If neither exists, print an error message and exit
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

# echo "Using SSH command: $SSH_CMD"
# echo "Connecting to: $REMOTE_USER@$REMOTE_HOST"

# Download files that haven't been downloaded yet
while IFS= read -r file; do
    # Generate the hash of the file path
    FILE_HASH=$(echo -n "$file" | sha256sum | awk '{print $1}')
    
    # Check if the file hash is already in the set
    if [ -z "${hash_set[$FILE_HASH]}" ]; then
        # Download the file
        $SCP_CMD "$REMOTE_USER@$REMOTE_HOST:$file" "$LOCAL_PATH"
        # Output the filename that is being copied
        echo "Copied file: $file"
        
        # Add the hash to the set and the tracking file
        echo "$FILE_HASH" >> "$TRACK_FILE"
        hash_set["$FILE_HASH"]=1
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
