#!/bin/bash
# Backup Minecraft server world + logs to Git

REPO_DIR="/opt/minecraft"
cd "$REPO_DIR" || exit 1

# Fix ownership & permissions
sudo chown -R minecraft:mc server
sudo chmod -R g+rwX server

# Add everything
git add -A

# Commit with timestamp
git commit -m "Auto-backup: $(date '+%Y-%m-%d %H:%M:%S')"

# Push
git push

