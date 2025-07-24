# Selendra Network Blockscout Explorer

This directory contains the complete Docker setup for running a Blockscout explorer specifically configured for the Selendra Network.

## 🌟 Features

- **Complete Blockscout Stack**: Backend, Frontend, Database, Redis, and all microservices
- **Selendra Network Configuration**: Pre-configured for Chain ID 1961
- **Health Monitoring**: Comprehensive health checks and monitoring
- **Easy Management**: Simple scripts for starting, stopping, and monitoring
- **Auto-restart**: Services automatically restart on failure
- **Performance Optimized**: Tuned for optimal performance

## 🚀 Quick Start

### Prerequisites

- Docker (20.10+)
- Docker Compose (2.0+)
- At least 4GB RAM available
- At least 20GB disk space

### 1. Start the Explorer

```bash
# Start all services
./start-selendra.sh start

# Or simply
./start-selendra.sh
```

### 2. Access the Explorer

Once all services are running (takes 2-5 minutes):

- **🌐 Web Interface**: http://localhost
- **🔧 API**: http://localhost/api
- **📊 Stats API**: http://localhost:8080
- **🔍 API Documentation**: http://localhost/api-docs

## 📋 Management Commands

### Service Management

```bash
# Start all services
./start-selendra.sh start

# Stop all services
./start-selendra.sh stop

# Restart all services
./start-selendra.sh restart

# Restart specific service
./start-selendra.sh restart backend

# Check service status
./start-selendra.sh status

# View logs
./start-selendra.sh logs

# View logs for specific service
./start-selendra.sh logs backend
```

### Health Monitoring

```bash
# Run health check
./healthcheck.sh

# Check system resources
./healthcheck.sh system

# Check for recent errors
./healthcheck.sh errors

# Run full diagnostic
./healthcheck.sh full
```

### Maintenance

```bash
# Check RPC connectivity
./start-selendra.sh rpc-check

# Clean up (removes all data!)
./start-selendra.sh cleanup
```

## 🏗️ Architecture

### Services Overview

| Service | Port | Description |
|---------|------|-------------|
| **proxy** | 80 | Nginx reverse proxy |
| **frontend** | 3000 | Next.js web interface |
| **backend** | 4000 | Elixir API server |
| **db** | 5432 | PostgreSQL database |
| **redis-db** | 6379 | Redis cache |
| **stats** | 8080 | Statistics service |
| **visualizer** | 8081 | Contract visualizer |
| **sig-provider** | 8082 | Signature provider |
| **smart-contract-verifier** | 8083 | Contract verifier |
| **user-ops-indexer** | 8084 | User operations indexer |
| **nft_media_handler** | 8085 | NFT media handler |

### Network Configuration

- **Network Name**: Selendra Network
- **Chain ID**: 1961
- **Currency**: SEL (Selendra)
- **Decimals**: 18
- **RPC URL**: https://rpc.selendra.org/
- **WebSocket**: wss://rpc.selendra.org/

## 🔧 Configuration Files

### Environment Files

- `envs/selendra-blockscout.env` - Backend configuration
- `envs/selendra-frontend.env` - Frontend configuration
- `envs/common-*.env` - Shared microservice configurations

### Docker Compose

- `selendra.yml` - Main compose file with all services
- Service definitions in `services/` directory

## 📊 Monitoring and Troubleshooting

### Health Checks

The system includes comprehensive health checks:

- **RPC Connectivity**: Verifies connection to Selendra network
- **Database**: Checks PostgreSQL connectivity
- **Redis**: Verifies cache connectivity
- **Services**: Monitors all service health
- **Resources**: Tracks disk and memory usage

### Common Issues

#### Services Won't Start

```bash
# Check logs
./start-selendra.sh logs

# Check specific service
./start-selendra.sh logs backend

# Restart problematic service
./start-selendra.sh restart backend
```

#### Database Issues

```bash
# Check database status
docker-compose -f selendra.yml -p selendra-blockscout exec db pg_isready

# View database logs
./start-selendra.sh logs db
```

#### Performance Issues

```bash
# Check system resources
./healthcheck.sh system

# Monitor container resources
docker stats
```

### Log Locations

Service logs are accessible via:
```bash
./start-selendra.sh logs [service_name]
```

## 🔄 Updates and Maintenance

### Updating Images

```bash
# Stop services
./start-selendra.sh stop

# Pull latest images
docker-compose -f selendra.yml pull

# Start services
./start-selendra.sh start
```

### Database Maintenance

The database will automatically migrate on startup. For manual operations:

```bash
# Access database
docker-compose -f selendra.yml -p selendra-blockscout exec db psql -U blockscout -d blockscout
```

### Backup and Restore

```bash
# Backup database
docker-compose -f selendra.yml -p selendra-blockscout exec db pg_dump -U blockscout blockscout > backup.sql

# Restore database (with services stopped)
cat backup.sql | docker-compose -f selendra.yml -p selendra-blockscout exec -T db psql -U blockscout -d blockscout
```

## 🔒 Security Considerations

- **Change Default Secrets**: Update `SECRET_KEY_BASE` in production
- **Network Access**: Consider firewall rules for production deployment
- **HTTPS**: Configure SSL/TLS for production use
- **Database Security**: Use strong passwords and restrict access
- **Regular Updates**: Keep Docker images updated

## 📈 Performance Tuning

### Resource Allocation

The configuration is optimized for:
- **RAM**: 4-8GB recommended
- **CPU**: 2-4 cores recommended
- **Storage**: SSD preferred, 50GB+ recommended

### Database Tuning

Key PostgreSQL settings are pre-configured:
- Connection pooling: 80 connections
- API pool size: 10 connections
- Optimized for read-heavy workloads

### Indexer Performance

- Batch sizes optimized for Selendra network
- Concurrent processing enabled
- Cache settings tuned for performance

## 🐛 Troubleshooting Guide

### Service Status Check
```bash
./start-selendra.sh status
```

### Individual Service Health
```bash
./healthcheck.sh health
```

### View Recent Errors
```bash
./healthcheck.sh errors
```

### Complete Diagnostic
```bash
./healthcheck.sh full
```

## 🤝 Support

For issues specific to this setup:
1. Check the logs: `./start-selendra.sh logs`
2. Run health check: `./healthcheck.sh full`
3. Consult the Blockscout documentation
4. Check Selendra network status

## 📝 License

This configuration follows the same license as the Blockscout project.