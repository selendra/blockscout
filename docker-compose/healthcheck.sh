#!/bin/bash

# Selendra Blockscout Health Check Script
# This script performs comprehensive health checks on all services

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMPOSE_FILE="selendra.yml"
PROJECT_NAME="selendra-blockscout"

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

# Check if service is running
check_service_running() {
    local service=$1
    if docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps "$service" | grep -q "Up"; then
        return 0
    else
        return 1
    fi
}

# Check HTTP endpoint
check_http_endpoint() {
    local url=$1
    local service_name=$2
    if curl -s -f "$url" > /dev/null 2>&1; then
        print_success "$service_name endpoint is healthy: $url"
        return 0
    else
        print_error "$service_name endpoint is not responding: $url"
        return 1
    fi
}

# Check database connectivity
check_database() {
    print_status "Checking database connectivity..."
    if docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" exec -T db pg_isready -U blockscout -d blockscout > /dev/null 2>&1; then
        print_success "Database is accessible"
        return 0
    else
        print_error "Database is not accessible"
        return 1
    fi
}

# Check Redis connectivity
check_redis() {
    print_status "Checking Redis connectivity..."
    if docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" exec -T redis-db redis-cli ping | grep -q "PONG"; then
        print_success "Redis is accessible"
        return 0
    else
        print_error "Redis is not accessible"
        return 1
    fi
}

# Check Selendra RPC
check_selendra_rpc() {
    print_status "Checking Selendra RPC connectivity..."
    local response=$(curl -s -X POST -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
        https://rpc.selendra.org/)
    
    if echo "$response" | grep -q "0x7a9"; then
        print_success "Selendra RPC is responding (Chain ID: 1961)"
        return 0
    else
        print_error "Selendra RPC is not responding correctly"
        echo "Response: $response"
        return 1
    fi
}

# Main health check function
perform_health_check() {
    echo "🏥 Selendra Blockscout Health Check"
    echo "=================================="
    echo ""
    
    local overall_health=0
    
    # Check external dependencies first
    print_status "Checking external dependencies..."
    check_selendra_rpc || overall_health=1
    echo ""
    
    # Check core services
    print_status "Checking core services..."
    
    # Database
    if check_service_running "db"; then
        print_success "Database container is running"
        check_database || overall_health=1
    else
        print_error "Database container is not running"
        overall_health=1
    fi
    
    # Redis
    if check_service_running "redis-db"; then
        print_success "Redis container is running"
        check_redis || overall_health=1
    else
        print_error "Redis container is not running"
        overall_health=1
    fi
    
    echo ""
    
    # Check application services
    print_status "Checking application services..."
    
    # Backend
    if check_service_running "backend"; then
        print_success "Backend container is running"
        check_http_endpoint "http://localhost:4000/api/v1/health" "Backend API" || overall_health=1
    else
        print_error "Backend container is not running"
        overall_health=1
    fi
    
    # Frontend
    if check_service_running "frontend"; then
        print_success "Frontend container is running"
        check_http_endpoint "http://localhost:3000/_next/static/chunks/pages/_app.js" "Frontend" || overall_health=1
    else
        print_error "Frontend container is not running"
        overall_health=1
    fi
    
    # Proxy
    if check_service_running "proxy"; then
        print_success "Proxy container is running"
        check_http_endpoint "http://localhost:8888/" "Web Interface" || overall_health=1
        check_http_endpoint "http://localhost:8888/api/v2/stats" "API via Proxy" || overall_health=1
    else
        print_error "Proxy container is not running"
        overall_health=1
    fi
    
    echo ""
    
    # Check microservices
    print_status "Checking microservices..."
    
    local microservices=("visualizer" "sig-provider" "smart-contract-verifier" "stats" "user-ops-indexer" "nft_media_handler")
    
    for service in "${microservices[@]}"; do
        if check_service_running "$service"; then
            print_success "$service is running"
        else
            print_warning "$service is not running (optional service)"
        fi
    done
    
    echo ""
    print_status "Service Status Overview:"
    docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
    
    echo ""
    
    if [ $overall_health -eq 0 ]; then
        print_success "🎉 All critical services are healthy!"
        echo ""
        echo "📱 Web Interface: http://localhost:8888"
        echo "🔧 API Endpoint: http://localhost:8888/api/v2/"
        echo "🔧 Direct Backend API: http://localhost:4000/api"
        echo "📊 Stats API: http://localhost:8081"
        return 0
    else
        print_error "❌ Some services are not healthy. Check the logs for more details."
        echo ""
        echo "💡 Troubleshooting tips:"
        echo "   - Check service logs: ./start-selendra.sh logs [service]"
        echo "   - Restart specific service: ./start-selendra.sh restart [service]"
        echo "   - Check resource usage: docker stats"
        return 1
    fi
}

# Check disk space
check_disk_space() {
    print_status "Checking disk space..."
    local available=$(df -h . | tail -1 | awk '{print $4}')
    local usage=$(df -h . | tail -1 | awk '{print $5}' | sed 's/%//')
    
    echo "Available space: $available"
    echo "Usage: $usage%"
    
    if [ "$usage" -gt 90 ]; then
        print_error "Disk usage is high ($usage%). Consider cleaning up."
        return 1
    elif [ "$usage" -gt 80 ]; then
        print_warning "Disk usage is getting high ($usage%)."
        return 0
    else
        print_success "Disk space is adequate ($usage% used)."
        return 0
    fi
}

# Check memory usage
check_memory_usage() {
    print_status "Checking memory usage..."
    local memory_info=$(free -h | grep Mem)
    echo "$memory_info"
    
    local usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [ "$usage" -gt 90 ]; then
        print_error "Memory usage is high ($usage%)."
        return 1
    elif [ "$usage" -gt 80 ]; then
        print_warning "Memory usage is getting high ($usage%)."
        return 0
    else
        print_success "Memory usage is normal ($usage%)."
        return 0
    fi
}

# Monitor logs for errors
check_recent_errors() {
    print_status "Checking for recent errors in logs..."
    local error_count=0
    
    # Check backend logs for errors
    local backend_errors=$(docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs --tail=100 backend 2>/dev/null | grep -i error | wc -l)
    if [ "$backend_errors" -gt 0 ]; then
        print_warning "Found $backend_errors error(s) in backend logs"
        error_count=$((error_count + backend_errors))
    fi
    
    # Check frontend logs for errors
    local frontend_errors=$(docker-compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs --tail=100 frontend 2>/dev/null | grep -i error | wc -l)
    if [ "$frontend_errors" -gt 0 ]; then
        print_warning "Found $frontend_errors error(s) in frontend logs"
        error_count=$((error_count + frontend_errors))
    fi
    
    if [ "$error_count" -eq 0 ]; then
        print_success "No recent errors found in logs"
        return 0
    else
        print_warning "Found $error_count total error(s) in recent logs"
        return 1
    fi
}

# Main execution
case "${1:-health}" in
    health)
        perform_health_check
        ;;
    system)
        check_disk_space
        check_memory_usage
        ;;
    errors)
        check_recent_errors
        ;;
    full)
        perform_health_check
        echo ""
        check_disk_space
        check_memory_usage
        check_recent_errors
        ;;
    *)
        echo "Selendra Blockscout Health Check Script"
        echo ""
        echo "Usage: $0 {health|system|errors|full}"
        echo ""
        echo "Commands:"
        echo "  health    Check service health (default)"
        echo "  system    Check system resources"
        echo "  errors    Check for recent errors in logs"
        echo "  full      Run all checks"
        exit 1
        ;;
esac