# Changelog

All notable changes to pgkeen will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of pgkeen
- PostgreSQL 16 base with AI/ML extensions
- Comprehensive extension documentation
- Docker Compose setup
- Size optimization (reduced from 5GB+ to ~3.2GB)

### Extensions Included
- pgvector - Vector similarity search
- pgml (PostgresML) - In-database machine learning
- pg_embedding - Advanced embedding operations
- vectorize - Automated vector operations
- PostGIS - Spatial data processing
- pg_partman - Partition management
- pg_cron - Job scheduling
- pgmq - Message queuing
- pgsql_http - HTTP client functionality
- And many more utility extensions

### Technical Details
- Python 3.10.14 compiled from source with optimizations
- Multi-layer Docker optimization
- Rust toolchain cleanup after pg-trunk installation
- Production-ready configuration

## [1.0.0] - 2025-06-20

### Added
- Initial public release
- Complete documentation suite
- Contributing guidelines
- MIT License
