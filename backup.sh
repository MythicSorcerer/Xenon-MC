#!/bin/bash

# ==============================
# Minecraft Backup Script
# ==============================

# Configuration
MINECRAFT_DIR="/opt/minecraft/server"
BACKUP_DIR="/opt/minecraft/backups"
RCON_PASSWORD="sagdab-ciNvis-4sewba"
RCON_PORT=25575
RETENTION_DAYS=14

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="minecraft_backup_$TIMESTAMP"

# ------------------------------
# Helper functions
# ------------------------------

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

send_rcon() {
    if ! mcrcon -H localhost -P "$RCON_PORT" -p "$RCON_PASSWORD" "$1" > /dev/null 2>&1; then
        log_message "Note: RCON command failed (RCON may be disabled or misconfigured)"
        return 1
    fi
    return 0
}

# ------------------------------
# Start backup
# ------------------------------

log_message "Starting backup process..."

if systemctl is-active --quiet minecraft.service; then
    log_message "Server is running, preparing for backup..."

    # Flush and pause saving
    send_rcon "save-off"
    send_rcon "save-all"
    send_rcon "say Backup starting... Server may lag briefly."
    sleep 5

    SERVER_RUNNING=true
else
    log_message "Server is not running, proceeding with cold backup..."
    SERVER_RUNNING=false
fi

# ------------------------------
# Create backup
# ------------------------------

log_message "Creating backup: $BACKUP_NAME"

cd "$MINECRAFT_DIR" || {
    log_message "ERROR: Could not cd into $MINECRAFT_DIR"
    exit 1
}

# Only back up existing files/folders
FILES_TO_BACKUP=(
    world
    server.properties
    whitelist.json
    ops.json
    banned-ips.json
    banned-players.json
)

if ! tar -czf "$BACKUP_DIR/$BACKUP_NAME.tar.gz" "${FILES_TO_BACKUP[@]}" 2>/tmp/backup_tar_error.log; then
    log_message "ERROR: tar failed! See /tmp/backup_tar_error.log"
    [ "$SERVER_RUNNING" = true ] && send_rcon "save-on"
    exit 1
fi

# ------------------------------
# Re-enable auto-save if needed
# ------------------------------

if [ "$SERVER_RUNNING" = true ]; then
    send_rcon "save-on"
    send_rcon "say Backup complete!"
fi

# ------------------------------
# Report success
# ------------------------------

if [ -f "$BACKUP_DIR/$BACKUP_NAME.tar.gz" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)
    log_message "Backup completed successfully: $BACKUP_NAME.tar.gz ($BACKUP_SIZE)"
else
    log_message "ERROR: Backup file missing after tar!"
    exit 1
fi

# ------------------------------
# Cleanup old backups
# ------------------------------

log_message "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "minecraft_backup_*.tar.gz" -mtime +$RETENTION_DAYS -delete

REMAINING_BACKUPS=$(ls -1 "$BACKUP_DIR"/minecraft_backup_*.tar.gz 2>/dev/null | wc -l)
log_message "Cleanup complete. $REMAINING_BACKUPS backup(s) remaining."

log_message "Backup process finished."

