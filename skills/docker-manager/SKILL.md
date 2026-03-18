# Docker Manager Skill

Comprehensive Docker container, image, network, and compose stack management for OpenClaw agents.

## Description

This skill provides complete Docker ecosystem management capabilities, from basic container operations to complex multi-service deployments. It includes resource monitoring, log management, and cleanup utilities.

## Commands

### Container Management
- `docker_status` — Running containers with resource usage
- `docker_logs <container>` — Recent logs from a container  
- `docker_restart <container>` — Restart a container safely
- `docker_stop <container>` — Stop a container gracefully
- `docker_start <container>` — Start a stopped container

### Compose Management
- `docker_compose_up <dir>` — Start a compose stack
- `docker_compose_down <dir>` — Stop a compose stack
- `docker_compose_status <dir>` — Status of compose services

### Monitoring & Maintenance
- `docker_stats` — Real-time resource usage
- `docker_prune` — Clean up unused images/volumes/networks
- `docker_health` — Overall Docker system health
- `docker_images` — List images with sizes
- `docker_networks` — List networks and their usage

## Scripts

### docker_status
```bash
#!/bin/bash
# docker_status - Show running containers with resource usage
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not installed or not in PATH"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "❌ Cannot connect to Docker daemon. Is Docker running?"
    exit 1
fi

echo "🐳 DOCKER CONTAINER STATUS"
echo "=========================="
echo "Docker version: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'Unknown')"
echo "Generated: $(date)"
echo

# Running containers count
running_count=$(docker ps -q | wc -l)
total_count=$(docker ps -aq | wc -l)
echo "📊 Containers: $running_count running, $total_count total"
echo

if [ "$running_count" -eq 0 ]; then
    echo "No containers currently running."
    exit 0
fi

# Container list with basic info
echo "🏃 RUNNING CONTAINERS"
echo "====================="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}"

echo
echo "📈 RESOURCE USAGE (Live)"
echo "========================"

# Get stats once (non-streaming)
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"

echo
echo "🔍 CONTAINER DETAILS"
echo "===================="

# Detailed info for each container
docker ps --format "{{.Names}}" | while read -r container_name; do
    if [ -n "$container_name" ]; then
        echo "📦 $container_name"
        echo "   Image: $(docker inspect "$container_name" --format '{{.Config.Image}}')"
        echo "   Created: $(docker inspect "$container_name" --format '{{.Created}}' | cut -d'T' -f1)"
        echo "   Restart Policy: $(docker inspect "$container_name" --format '{{.HostConfig.RestartPolicy.Name}}')"
        
        # Check if container has health check
        health_check=$(docker inspect "$container_name" --format '{{.Config.Healthcheck}}' 2>/dev/null || echo '<nil>')
        if [ "$health_check" != "<nil>" ]; then
            health_status=$(docker inspect "$container_name" --format '{{.State.Health.Status}}' 2>/dev/null || echo 'unknown')
            echo "   Health: $health_status"
        fi
        echo
    fi
done
```

### docker_logs
```bash
#!/bin/bash
# docker_logs - Show recent logs from a container
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: docker_logs <container_name_or_id>"
    echo "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    exit 1
fi

CONTAINER="$1"
LINES="${2:-50}"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "❌ Container '$CONTAINER' not found or not running"
    echo "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}"
    exit 1
fi

echo "📋 LOGS for $CONTAINER (last $LINES lines)"
echo "$(printf '=%.0s' {1..50})"
echo "Container: $CONTAINER"
echo "Timestamp: $(date)"
echo "$(printf '=%.0s' {1..50})"

# Show logs with timestamps
docker logs --tail "$LINES" --timestamps "$CONTAINER" 2>&1 | \
    while IFS= read -r line; do
        # Colorize common log levels
        if [[ "$line" =~ ERROR|error|Error|FATAL|fatal|Fatal ]]; then
            echo -e "\033[0;31m$line\033[0m"  # Red
        elif [[ "$line" =~ WARN|warn|Warn|WARNING|warning|Warning ]]; then
            echo -e "\033[1;33m$line\033[0m"  # Yellow
        elif [[ "$line" =~ INFO|info|Info ]]; then
            echo -e "\033[0;32m$line\033[0m"  # Green
        elif [[ "$line" =~ DEBUG|debug|Debug ]]; then
            echo -e "\033[0;36m$line\033[0m"  # Cyan
        else
            echo "$line"
        fi
    done

echo
echo "💡 Tip: Use 'docker logs -f $CONTAINER' for live log streaming"
```

### docker_restart
```bash
#!/bin/bash
# docker_restart - Safely restart a container
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: docker_restart <container_name_or_id>"
    echo "Available containers:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
    exit 1
fi

CONTAINER="$1"
TIMEOUT="${2:-30}"

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "❌ Container '$CONTAINER' not found"
    exit 1
fi

echo "🔄 RESTARTING CONTAINER: $CONTAINER"
echo "===================================="
echo "Container: $CONTAINER"
echo "Timeout: ${TIMEOUT}s"
echo "Timestamp: $(date)"
echo

# Check current status
current_status=$(docker inspect "$CONTAINER" --format '{{.State.Status}}')
echo "Current status: $current_status"

# If it's running, gracefully stop first
if [ "$current_status" = "running" ]; then
    echo "🛑 Stopping container gracefully..."
    if docker stop --time="$TIMEOUT" "$CONTAINER"; then
        echo "✅ Container stopped successfully"
    else
        echo "⚠️  Container didn't stop gracefully, forcing stop..."
        docker kill "$CONTAINER"
    fi
fi

# Start the container
echo "🚀 Starting container..."
if docker start "$CONTAINER"; then
    echo "✅ Container started successfully"
    
    # Wait a moment for startup
    sleep 2
    
    # Check final status
    new_status=$(docker inspect "$CONTAINER" --format '{{.State.Status}}')
    echo "New status: $new_status"
    
    # Show logs to verify startup
    echo
    echo "📋 Recent startup logs:"
    docker logs --tail 10 --timestamps "$CONTAINER" 2>&1 | tail -5
else
    echo "❌ Failed to start container"
    exit 1
fi
```

### docker_compose_up
```bash
#!/bin/bash
# docker_compose_up - Start a compose stack
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: docker_compose_up <directory_with_docker-compose.yml>"
    exit 1
fi

COMPOSE_DIR="$1"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"

if [ ! -d "$COMPOSE_DIR" ]; then
    echo "❌ Directory '$COMPOSE_DIR' does not exist"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ] && [ ! -f "$COMPOSE_DIR/docker-compose.yaml" ]; then
    echo "❌ No docker-compose.yml or docker-compose.yaml found in '$COMPOSE_DIR'"
    exit 1
fi

# Use docker-compose or docker compose (newer)
COMPOSE_CMD="docker compose"
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        echo "❌ Neither 'docker compose' nor 'docker-compose' found"
        exit 1
    fi
fi

echo "🚀 STARTING COMPOSE STACK"
echo "========================="
echo "Directory: $COMPOSE_DIR"
echo "Compose command: $COMPOSE_CMD"
echo "Timestamp: $(date)"
echo

cd "$COMPOSE_DIR"

# Show what we're about to start
echo "📋 Services in compose file:"
$COMPOSE_CMD config --services 2>/dev/null | sed 's/^/  - /'

echo
echo "🏁 Starting services..."
if $COMPOSE_CMD up -d; then
    echo "✅ Compose stack started successfully"
    
    # Show running services
    echo
    echo "📊 Service status:"
    $COMPOSE_CMD ps
    
    # Show recent logs
    echo
    echo "📋 Recent logs (last 5 lines per service):"
    $COMPOSE_CMD logs --tail=5
else
    echo "❌ Failed to start compose stack"
    echo
    echo "🔍 Checking for errors..."
    $COMPOSE_CMD logs --tail=10
    exit 1
fi
```

### docker_compose_down
```bash
#!/bin/bash
# docker_compose_down - Stop a compose stack
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "Usage: docker_compose_down <directory_with_docker-compose.yml> [--volumes]"
    exit 1
fi

COMPOSE_DIR="$1"
REMOVE_VOLUMES="${2:-}"

if [ ! -d "$COMPOSE_DIR" ]; then
    echo "❌ Directory '$COMPOSE_DIR' does not exist"
    exit 1
fi

# Use docker-compose or docker compose
COMPOSE_CMD="docker compose"
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        echo "❌ Neither 'docker compose' nor 'docker-compose' found"
        exit 1
    fi
fi

echo "🛑 STOPPING COMPOSE STACK"
echo "========================="
echo "Directory: $COMPOSE_DIR"
echo "Remove volumes: $([ "$REMOVE_VOLUMES" = "--volumes" ] && echo "Yes" || echo "No")"
echo "Timestamp: $(date)"
echo

cd "$COMPOSE_DIR"

# Show current status
echo "📊 Current service status:"
$COMPOSE_CMD ps

echo
echo "🛑 Stopping services..."

# Construct command
DOWN_CMD="$COMPOSE_CMD down"
if [ "$REMOVE_VOLUMES" = "--volumes" ]; then
    DOWN_CMD="$DOWN_CMD --volumes"
    echo "⚠️  This will remove all volumes and their data!"
fi

if $DOWN_CMD; then
    echo "✅ Compose stack stopped successfully"
    
    # Verify everything is down
    echo
    echo "📊 Final status:"
    $COMPOSE_CMD ps || echo "All services stopped"
else
    echo "❌ Error stopping compose stack"
    exit 1
fi
```

### docker_stats
```bash
#!/bin/bash
# docker_stats - Real-time resource usage monitoring
set -euo pipefail

DURATION="${1:-30}"

echo "📊 DOCKER RESOURCE MONITORING"
echo "============================="
echo "Monitoring for ${DURATION} seconds..."
echo "Press Ctrl+C to stop early"
echo

# Check if any containers are running
running_count=$(docker ps -q | wc -l)
if [ "$running_count" -eq 0 ]; then
    echo "No containers currently running."
    exit 0
fi

# Show current snapshot first
echo "📸 Current snapshot:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}"

echo
echo "🔴 Starting live monitoring (${DURATION}s)..."
sleep 2

# Live monitoring with timeout
timeout "$DURATION" docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" 2>/dev/null || true

echo
echo "✅ Monitoring complete"

# Show summary statistics
echo
echo "📈 SUMMARY"
echo "=========="

# Container count
echo "Active containers: $running_count"

# Overall Docker system info
echo "Docker info:"
docker system df | grep -E "TYPE|Images|Containers|Local" | sed 's/^/  /'

# Memory usage summary
echo
echo "💾 Total container memory usage:"
docker stats --no-stream --format "{{.MemUsage}}" | awk -F' / ' '{
    gsub(/[^0-9.]/, "", $1); 
    total+=$1
} END {
    if (total < 1024) printf "  %.1f MB\n", total
    else printf "  %.1f GB\n", total/1024
}'
```

### docker_prune
```bash
#!/bin/bash
# docker_prune - Clean up unused Docker resources
set -euo pipefail

DRY_RUN="${1:-}"

echo "🧹 DOCKER CLEANUP UTILITY"
echo "========================="
echo "Timestamp: $(date)"

if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "🔍 DRY RUN MODE - No changes will be made"
fi
echo

# Show current disk usage
echo "📊 Current Docker disk usage:"
docker system df

echo
echo "🗑️  Resources to be cleaned:"

# Count what will be removed
if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "📦 Unused containers:"
    docker container ls -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" | head -10

    echo "🖼️  Unused images:"
    docker images --filter "dangling=true" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -10

    echo "🌐 Unused networks:"
    docker network ls --filter "dangling=true"

    echo "💾 Unused volumes:"
    docker volume ls --filter "dangling=true"
    
    echo
    echo "💡 Run without --dry-run to perform actual cleanup"
    exit 0
fi

echo "⚠️  About to remove unused Docker resources..."
echo "This will remove:"
echo "  - Stopped containers"
echo "  - Unused networks" 
echo "  - Dangling images"
echo "  - Unused build cache"
echo

read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo "🧹 Starting cleanup..."

# Clean up containers
echo "📦 Removing stopped containers..."
docker container prune -f

# Clean up images
echo "🖼️  Removing unused images..."
docker image prune -f

# Clean up networks
echo "🌐 Removing unused networks..."
docker network prune -f

# Clean up volumes (be more careful here)
echo "💾 Checking for unused volumes..."
unused_volumes=$(docker volume ls -qf dangling=true | wc -l)
if [ "$unused_volumes" -gt 0 ]; then
    echo "Found $unused_volumes unused volume(s)"
    read -p "Remove unused volumes? This will DELETE DATA! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker volume prune -f
        echo "✅ Unused volumes removed"
    else
        echo "⏭️  Skipping volume cleanup"
    fi
else
    echo "✅ No unused volumes found"
fi

# Clean up build cache
echo "🔨 Removing build cache..."
docker builder prune -f

echo
echo "✅ Cleanup complete!"
echo
echo "📊 New Docker disk usage:"
docker system df
```

### docker_health
```bash
#!/bin/bash
# docker_health - Overall Docker system health check
set -euo pipefail

echo "🏥 DOCKER SYSTEM HEALTH CHECK"
echo "=============================="
echo "Timestamp: $(date)"
echo

# Check if Docker is installed and running
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ Docker not installed"
    exit 1
fi

echo "✅ Docker installed: $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo 'Unknown')"

if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker daemon not running or not accessible"
    exit 1
fi

echo "✅ Docker daemon running"

# System resources
echo
echo "📊 SYSTEM RESOURCES"
echo "==================="
docker system df

# Container health
echo
echo "🐳 CONTAINER HEALTH"
echo "==================="
running_containers=$(docker ps -q | wc -l)
total_containers=$(docker ps -aq | wc -l)
echo "Containers: $running_containers running, $total_containers total"

if [ "$running_containers" -gt 0 ]; then
    echo
    echo "Container status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
    
    # Check for unhealthy containers
    unhealthy=$(docker ps --filter "health=unhealthy" -q | wc -l)
    if [ "$unhealthy" -gt 0 ]; then
        echo "⚠️  $unhealthy unhealthy container(s) found:"
        docker ps --filter "health=unhealthy" --format "table {{.Names}}\t{{.Status}}"
    else
        echo "✅ All containers with health checks are healthy"
    fi
fi

# Resource usage summary
if [ "$running_containers" -gt 0 ]; then
    echo
    echo "📈 RESOURCE USAGE"
    echo "================="
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}"
fi

# Storage usage warnings
echo
echo "💾 STORAGE ANALYSIS"
echo "=================="

# Parse docker system df output
docker system df | while read -r line; do
    if [[ "$line" =~ ^Images ]]; then
        size=$(echo "$line" | awk '{print $(NF-1)}')
        if [[ "$size" =~ ([0-9.]+)GB ]] && (( $(echo "${BASH_REMATCH[1]} > 10" | bc -l 2>/dev/null || echo 0) )); then
            echo "⚠️  Large image storage: $size"
        fi
    elif [[ "$line" =~ ^Containers ]]; then
        size=$(echo "$line" | awk '{print $(NF-1)}')
        if [[ "$size" =~ ([0-9.]+)GB ]] && (( $(echo "${BASH_REMATCH[1]} > 5" | bc -l 2>/dev/null || echo 0) )); then
            echo "⚠️  Large container storage: $size"
        fi
    fi
done

# Check for old images
old_images=$(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}" | grep -c "months\|year" 2>/dev/null || echo 0)
if [ "$old_images" -gt 0 ]; then
    echo "⚠️  $old_images image(s) older than 1 month found"
fi

# Network health
echo
echo "🌐 NETWORK HEALTH" 
echo "================="
network_count=$(docker network ls | wc -l)
echo "Networks: $((network_count - 1))"  # Subtract header

# Check for network conflicts
if docker network ls --format "{{.Name}}" | grep -q "br-"; then
    echo "✅ Custom bridge networks detected"
fi

# Overall health score
echo
echo "🎯 OVERALL HEALTH"
echo "================="

health_score=100
issues=()

# Deduct points for issues
if [ "$unhealthy" -gt 0 ]; then
    health_score=$((health_score - 20))
    issues+=("unhealthy containers")
fi

if [ "$old_images" -gt 5 ]; then
    health_score=$((health_score - 10))
    issues+=("many old images")
fi

# Check for stopped containers
stopped_containers=$(docker ps -aq --filter "status=exited" | wc -l)
if [ "$stopped_containers" -gt 10 ]; then
    health_score=$((health_score - 10))
    issues+=("many stopped containers")
fi

if [ ${#issues[@]} -eq 0 ]; then
    echo "✅ Docker system health: ${health_score}% - Excellent"
else
    echo "⚠️  Docker system health: ${health_score}% - Issues: ${issues[*]}"
    echo
    echo "💡 Recommendations:"
    for issue in "${issues[@]}"; do
        case "$issue" in
            "unhealthy containers")
                echo "  - Check logs for unhealthy containers and restart if needed"
                ;;
            "many old images")
                echo "  - Run 'docker_prune' to clean up old images"
                ;;
            "many stopped containers")
                echo "  - Run 'docker_prune' to remove stopped containers"
                ;;
        esac
    done
fi
```

## Installation

Copy this skill to your OpenClaw skills directory:
```bash
cp -r docker-manager ~/.openclaw/skills/
```

Or install via ClawHub (when published):
```bash
openclaw skill install docker-manager
```

## Dependencies

- Docker Engine (tested with 20.10+)
- Either `docker compose` (newer) or `docker-compose` (legacy)
- Standard Linux utilities (awk, grep, sed, etc.)

## Security Notes

- Scripts use `docker` command directly - ensure proper Docker group membership
- Compose operations change directory - paths are validated before execution  
- Volume removal requires explicit confirmation
- No automatic container deletion without user confirmation

## Integration Examples

### Heartbeat Monitoring
Add to `HEARTBEAT.md`:
```bash
# Check Docker health every ~4 hours
if docker_health | grep -q "Issues:"; then
    echo "🐳 Docker issues detected"
    docker_health
fi
```

### Automated Cleanup
```bash
# Weekly cleanup (add to cron)
# Run every Sunday at 2 AM
0 2 * * 0 /path/to/docker_prune --auto-confirm 2>&1 | logger -t docker_cleanup
```

### Container Restart Automation
```bash
# Auto-restart unhealthy containers
unhealthy_containers=$(docker ps --filter "health=unhealthy" --format "{{.Names}}")
for container in $unhealthy_containers; do
    echo "Restarting unhealthy container: $container"
    docker_restart "$container"
done
```