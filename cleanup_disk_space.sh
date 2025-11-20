#!/bin/bash
"""
CloudShell Disk Space Cleanup Commands
Clean up files older than 1 month from 100% utilized filesystems
"""

echo "=== CloudShell Disk Space Cleanup ==="

# Check current disk usage
echo "Current disk usage:"
df -h

echo ""
echo "🧹 Cleaning up old files (older than 30 days)..."

# 1. Clean up temporary files older than 30 days
echo "Cleaning /tmp (older than 30 days)..."
find /tmp -type f -mtime +30 -exec rm -f {} \; 2>/dev/null || echo "Some files in /tmp could not be deleted (permissions)"

# 2. Clean up Docker build cache and old containers/images
echo "Cleaning Docker cache..."
docker system prune -af --filter "until=720h" 2>/dev/null || echo "Docker cleanup completed"

# 3. Clean up old log files
echo "Cleaning old log files..."
find /var/log -name "*.log" -mtime +30 -exec rm -f {} \; 2>/dev/null || true
find /var/log -name "*.log.*" -mtime +30 -exec rm -f {} \; 2>/dev/null || true

# 4. Clean up old cache files in home directory
echo "Cleaning old cache files in home..."
find /home -name ".cache" -type d -exec find {} -mtime +30 -delete \; 2>/dev/null || true

# 5. Clean up buildkit cache specifically
echo "Cleaning buildkit cache..."
docker builder prune -af --filter "until=720h" 2>/dev/null || echo "Buildkit cache cleaned"

# 6. Clean up specific large Docker build artifacts
echo "Removing Docker build artifacts..."
rm -rf /tmp/buildkitd-config* 2>/dev/null || true
rm -rf /tmp/dns-container-* 2>/dev/null || true
rm -rf /tmp/build* 2>/dev/null || true

# 7. Clean up AWS CLI cache
echo "Cleaning AWS CLI cache..."
find ~/.aws -name "cli" -type d -exec find {} -mtime +30 -delete \; 2>/dev/null || true

# 8. Clean up Python cache files
echo "Cleaning Python cache..."
find /home -name "__pycache__" -type d -exec rm -rf {} \; 2>/dev/null || true
find /home -name "*.pyc" -mtime +30 -delete 2>/dev/null || true

# 9. Clean up package manager caches
echo "Cleaning package caches..."
apt-get clean 2>/dev/null || true
rm -rf /var/cache/apt/archives/*.deb 2>/dev/null || true

echo ""
echo "✅ Cleanup completed! New disk usage:"
df -h

echo ""
echo "📊 Largest directories in root filesystem:"
du -sh /* 2>/dev/null | sort -hr | head -10

echo ""
echo "💡 Additional manual cleanup options:"
echo "1. Remove old Docker images: docker rmi \$(docker images -q)"
echo "2. Remove all stopped containers: docker container prune -f"  
echo "3. Check for large files: find / -size +100M -ls 2>/dev/null"