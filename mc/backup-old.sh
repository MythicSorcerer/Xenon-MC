#!/bin/bash

# Configuration
MINECRAFT_DIR="/opt/minecraft/server"
BACKUP_DIR="/opt/minecraft/backups"
RCON_PASSWORD="sagdab-ciNvis-4sewba"
RETENTION_DAYS=14

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="minecraft_backup_$TIMESTAMP"

# Function to send rcon commands
send_rcon() {
    if ! mcrcon -H localhost -P 25575 -p "$RCON_PASSWORD" "$1" > /dev/null 2>&1; then
        log_message "Warning: RCON command failed, server might not be running with RCON enabled"
        return 1
    fi
    return 0
}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message "Starting backup process..."

# Check if server is running
if systemctl is-active --quiet minecraft.service; then
    log_message "Server is running, preparing for backup..."
    
    # Disable auto-save and save the world
    send_rcon "save-off"
    send_rcon "save-all"
    send_rcon "say Backup starting... Server may lag briefly."
    
    # Wait for save to complete
    sleep 5
    
    SERVER_RUNNING=true
else
    log_message "Server is not running, proceeding with backup..."
    SERVER_RUNNING=false
fi

# Create backup
log_message "Creating backup: $BACKUP_NAME"
cd "$MINECRAFT_DIR"
tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" world world_nether world_the_end server.properties whitelist.json ops.json banned-ips.json banned-players.json

# Re-enable auto-save if server was running
if [ "$SERVER_RUNNING" = true ]; then
    send_rcon "save-on"
    send_rcon "say Backup complete!"
fi

# Check if backup was created successfully
if [ -f "$BACKUP_DIR/$BACKUP_NAME.tar.gz" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)
    log_message "Backup completed successfully: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"
else
    log_message "ERROR: Backup failed!"
    exit 1
fi

# Clean up old backups
log_message "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "minecraft_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

REMAINING_BACKUPS=$(ls -1 "$BACKUP_DIR"/minecraft_backup_*.tar.gz 2>/dev/null | wc -l)
log_message "Cleanup complete. $REMAINING_BACKUPS backup(s) remaining."

log_message "Backup process finished."
