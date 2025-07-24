#!/bin/bash

# Selendra Blockscout Explorer Startup Script
# This script starts the complete Blockscout stack for Selendra Network

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="selendra.yml"
PROJECT_NAME="selendra-blockscout"
LOG_DIR="./logs"
MAX_WAIT_TIME=300 # 5 minutes

# Create logs directory
mkdir -p "$LOG_DIR"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✅ $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠️  $1"
}

print_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ❌ $1"
}

# Function to check if a service is healthy
check_service_health() {
    local service_name=$1
    local max_attempts=60
    local attempt=0
    
    print_status "Checking health of $service_name..."
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps "$service_name" | grep -q "healthy\|Up"; then
            print_success "$service_name is healthy"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    print_error "$service_name failed to become healthy within timeout"
    return 1
}

# Function to wait for service startup
wait_for_service() {
    local service_name=$1
    local port=$2
    local max_attempts=60
    local attempt=0
    
    print_status "Waiting for $service_name to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" exec -T "$service_name" nc -z localhost "$port" 2>/dev/null; then
            print_success "$service_name is ready on port $port"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 5
    done
    
    print_error "$service_name failed to start within timeout"
    return 1
}

# Function to check RPC connectivity
check_rpc_connectivity() {
    print_status "Checking Selendra RPC connectivity..."
    
    if curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        https://rpc.selendra.org/ | grep -q "0x7a9"; then
        print_success "Selendra RPC is accessible (Chain ID: 1961)"
        return 0
    else
        print_error "Failed to connect to Selendra RPC"
        return 1
    fi
}

# Function to show service status
show_service_status() {
    print_status "Service Status:"
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
}

# Function to show service logs
show_logs() {
    local service=$1
    if [ -n "$service" ]; then
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f "$service"
    else
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f
    fi
}

# Function to stop services
stop_services() {
    print_status "Stopping Selendra Blockscout services..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down
    print_success "Services stopped"
}

# Function to clean up (remove containers and volumes)
cleanup() {
    print_warning "This will remove all containers and volumes. Data will be lost!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up..."
        docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down -v --remove-orphans
        docker system prune -f
        print_success "Cleanup completed"
    fi
}

# Function to restart a specific service
restart_service() {
    local service=$1
    if [ -z "$service" ]; then
        print_error "Please specify a service name"
        return 1
    fi
    
    print_status "Restarting $service..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" restart "$service"
    check_service_health "$service"
}

# Function to start services
start_services() {
    print_status "Starting Selendra Blockscout Explorer..."
    
    # Check if docker-compose file exists
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Docker compose file $COMPOSE_FILE not found!"
        exit 1
    fi
    
    # Check RPC connectivity first
    if ! check_rpc_connectivity; then
        print_warning "RPC connectivity check failed, but continuing..."
    fi
    
    # Pull latest images
    print_status "Pulling latest Docker images..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" pull
    
    # Start core services first
    print_status "Starting core services (Redis, Database)..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d redis-db db-init
    
    # Wait for database initialization
    print_status "Waiting for database initialization..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d db
    sleep 10
    
    # Start backend service
    print_status "Starting backend service..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d backend
    
    # Wait for backend to be healthy
    if ! check_service_health "backend"; then
        print_error "Backend service failed to start properly"
        show_logs "backend"
        exit 1
    fi
    
    # Start microservices
    print_status "Starting microservices..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d \
        nft_media_handler visualizer sig-provider smart-contract-verifier
    
    # Start stats services
    print_status "Starting stats services..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d stats-db-init
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d stats-db stats
    
    # Start user-ops-indexer
    print_status "Starting user-ops-indexer..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d user-ops-indexer
    
    # Start frontend
    print_status "Starting frontend..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d frontend
    
    # Wait for frontend to be healthy
    if ! check_service_health "frontend"; then
        print_error "Frontend service failed to start properly"
        show_logs "frontend"
        exit 1
    fi
    
    # Start proxy (nginx)
    print_status "Starting proxy service..."
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d proxy
    
    # Final health check
    if check_service_health "proxy"; then
        print_success "🎉 Selendra Blockscout Explorer is ready!"
        echo ""
        print_status "Access URLs:"
        echo "  📱 Web Interface: http://localhost"
        echo "  🔧 API: http://localhost/api"
        echo "  📊 Stats: http://localhost:8082"
        echo ""
        print_status "Useful commands:"
        echo "  📋 View status: $0 status"
        echo "  📄 View logs: $0 logs [service]"
        echo "  🔄 Restart service: $0 restart [service]"
        echo "  🛑 Stop services: $0 stop"
        echo ""
    else
        print_error "Proxy service failed to start properly"
        show_logs "proxy"
        exit 1
    fi
}

# Main script logic
case "${1:-start}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        if [ -n "$2" ]; then
            restart_service "$2"
        else
            stop_services
            sleep 5
            start_services
        fi
        ;;
    status)
        show_service_status
        ;;
    logs)
        show_logs "$2"
        ;;
    cleanup)
        cleanup
        ;;
    rpc-check)
        check_rpc_connectivity
        ;;
    *)
        echo "Selendra Blockscout Explorer Management Script"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs|cleanup|rpc-check}"
        echo ""
        echo "Commands:"
        echo "  start                 Start all services"
        echo "  stop                  Stop all services"
        echo "  restart [service]     Restart all services or specific service"
        echo "  status                Show service status"
        echo "  logs [service]        Show logs for all services or specific service"
        echo "  cleanup               Remove all containers and volumes (destructive)"
        echo "  rpc-check             Check Selendra RPC connectivity"
        echo ""
        echo "Examples:"
        echo "  $0 start"
        echo "  $0 logs backend"
        echo "  $0 restart frontend"
        echo "  $0 status"
        exit 1
        ;;
esac