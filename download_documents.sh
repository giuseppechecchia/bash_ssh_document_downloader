#!/bin/bash

# Path to the .env file
ENV_FILE="/path/to/config/.env"

# Load the .env file
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Error: Configuration file .env not found at path $ENV_FILE"
    exit 1
fi

# Build the SSH command based on the presence of the SSH key
if [ -n "$SSH_KEY" ]; then
    SSH_CMD="ssh -i $SSH_KEY"
    SCP_CMD="scp -i $SSH_KEY"
else
    SSH_CMD="ssh"
    SCP_CMD="scp"
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
        # Download the file
        $SCP_CMD "$REMOTE_USER@$REMOTE_HOST:$file" "$LOCAL_PATH"
        
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
