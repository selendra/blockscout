# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## About Blockscout

Blockscout is an open-source blockchain explorer for EVM-compatible chains, built as an Elixir umbrella application. It provides comprehensive blockchain data indexing, APIs, and web interfaces for viewing transactions, blocks, addresses, and smart contracts across multiple blockchain networks.

## Architecture Overview

### Application Structure
Blockscout is organized as an Elixir umbrella application with 6 main apps in the `apps/` directory:

- **`explorer/`** - Data layer and business logic (Ecto schemas, database operations, ETL import pipeline)
- **`indexer/`** - Backend data fetching and processing (real-time blockchain indexing via supervised GenServers)
- **`ethereum_jsonrpc/`** - Blockchain RPC communication layer (abstracts JSON-RPC interactions with nodes)
- **`block_scout_web/`** - Web interface and API layer (Phoenix web app, REST/GraphQL APIs, WebSocket channels)
- **`utils/`** - Shared utilities and helpers
- **`nft_media_handler/`** - NFT metadata and media processing

### Data Flow
```
Blockchain Node → EthereumJSONRPC → Indexer → Explorer.Chain.Import → PostgreSQL
                                      ↓
                               BufferedTasks & Transformers
                                      ↓
                              Explorer (Data Access) → BlockScoutWeb (APIs/UI)
```

### Multi-Chain Support
Supports multiple blockchain types through configurable client variants (Geth, Nethermind, Besu, Erigon) and chain-specific features for Arbitrum, Optimism, Polygon zkEVM, zkSync, Scroll, Celo, and others.

## Development Commands

### Building the Project
```bash
# Install and compile dependencies
mix do deps.get, local.rebar, deps.compile, compile

# Frontend assets
cd apps/block_scout_web/assets
npm install
npm run build      # Development build
npm run deploy     # Production build
npm run watch      # Watch mode for development
```

### Running Tests
```bash
# All tests
mix test

# Comprehensive test suite (formatting, linting, security, dialyzer, tests)
./bin/test

# Frontend tests
cd apps/block_scout_web/assets && npm test
```

### Code Quality
```bash
# Format code
mix format
mix format --check-formatted

# Linting and analysis
mix credo --strict
mix dialyzer --halt-exit-status
mix sobelow --config
```

### Development Server
```bash
# Database setup
mix ecto.create && mix ecto.migrate

# Start server
mix phx.server                    # Standard startup
iex -S mix phx.server            # With interactive shell

# Access at http://localhost:4000
```

### Database Management
```bash
mix ecto.create         # Create database
mix ecto.migrate        # Run migrations
mix ecto.setup          # Create, migrate, and seed
mix ecto.reset          # Drop and recreate
```

### Docker Development
```bash
# Standard Docker Compose
cd docker-compose
docker-compose up --build    # Build and start all services
docker-compose up           # Start with existing images

# Selendra-specific setup
./docker-compose/start-selendra.sh           # Start Selendra setup
./docker-compose/start-selendra.sh status    # Check status
./docker-compose/start-selendra.sh logs [service]  # View logs
./docker-compose/start-selendra.sh stop      # Stop services
```

## Configuration System

### Environment Files
- `config/config.exs` - Base configuration
- `config/dev.exs` - Development overrides
- `config/prod.exs` - Production overrides  
- `config/runtime.exs` - Runtime configuration from environment variables
- `config/runtime/` - Environment-specific runtime configs

### App-Specific Configuration
Each app has chain-specific configs in `config/dev/` and `config/prod/` directories for different blockchain clients and features.

### Configuration Best Practices
- Favor **runtime configuration** over compile-time when possible
- Use `Utils.RuntimeEnvHelper` for runtime configs
- Use `Utils.CompileTimeEnvHelper` only when schema modifications are needed
- New features should use runtime config with pattern matching
- Check `CONTRIBUTING.md` for detailed configuration guidelines

## API Structure

### API Versions
- **API v1** (`/api/v1/`) - Legacy RPC-style endpoints, Etherscan-compatible, GraphQL at `/v1/graphql`
- **API v2** (`/api/v2/`) - Modern REST API with comprehensive data access and chain-specific endpoints

### Key Endpoints
- Core data: `/blocks`, `/transactions`, `/addresses`
- Token data: `/tokens`, `/token-transfers`
- Smart contracts: `/smart-contracts`
- Chain-specific: `/optimism`, `/arbitrum`, `/zksync`
- Analytics: `/stats`, `/charts`
- Search: `/search`

### Real-time Features
Phoenix Channels provide WebSocket connections for live updates on blocks, transactions, addresses, and tokens.

## Development Guidelines

### Naming Conventions (from CONTRIBUTING.md)
- Use full names, avoid abbreviations: "transaction" not "tx", "transaction_hash" not "tx_hash"
- Property names ending with `_block_number` should return numbers
- Hash fields should end with `_hash` and return hex strings
- Aggregation fields use plural + suffix: `transactions_count`, `blocks_count`

### Code Patterns
- Follow existing patterns in similar components
- Use pattern matching instead of conditional compilation where possible
- Check for existing libraries in mix.exs before adding new dependencies
- Follow security best practices, never commit secrets or keys

## Release and Production

### Production Commands
```bash
# In production releases
./rel/commands/migrate.sh    # Run migrations
./rel/commands/seed.sh       # Seed database
```

### Chain-Specific Deployments
Various Docker Compose configurations available for different blockchain clients and networks in the `docker-compose/` directory.