# bash_ssh_document_downloader
A poorly written bash script that allows downloading stuff via SSH.

## Overview

This repository contains a Bash script that facilitates downloading specific files from a remote server via SSH. The script is designed to track files that have already been downloaded, preventing duplicates from being downloaded again. It can handle various file types (such as `.pdf`, `.doc`, `.docx`, `.rtf`, and `.txt`) and works recursively through directories on the remote server.

## Important Notice

**This script is not intended for production use.** It was created as an exercise and has not been thoroughly tested in enterprise environments. The script may contain inefficiencies and potential bugs that could affect its performance or reliability when handling large-scale or critical tasks.

## Use Case

This script was designed for a very specific use case where the user needs to download files via SSH while avoiding duplicates by tracking already downloaded files. However, in most scenarios, tools like `rsync` or other file synchronization solutions would be more appropriate and efficient.

## Features

- **Download files via SSH:** The script connects to a remote server using SSH and downloads files with specific extensions.
- **Track downloaded files:** The script maintains a log of downloaded files using hashed file paths to prevent re-downloading.
- **Handle large numbers of files:** The script includes a mechanism to manage the size of the tracking log by retaining only the most recent entries.

## How It Works

1. **Configuration:** The script reads connection details, paths, and other parameters from a `.env` file located in a known path.
2. **File Retrieval:** The script connects to the remote server, retrieves a list of files, and filters them based on specific file extensions.
3. **Download Process:** It downloads files that have not been previously downloaded, as tracked by a log file.
4. **Log Management:** If the log file grows too large, the script trims it to retain only the most recent entries.

## Limitations

- **Not production-ready:** This script has been created for educational purposes and should not be used in production environments without thorough testing and modifications.
- **Specific use case:** The script is tailored to a specific need that may not apply to most scenarios where file transfer is required.
- **Better alternatives exist:** For most file transfer tasks, tools like `rsync` or other synchronization utilities would be more efficient and reliable.

## Getting Started

Clone this repository:
   ```bash
   git clone https://github.com/yourusername/ssh-file-downloader.git
   cd ssh-file-downloader
```

Compile .env file with your data.

Run it.
