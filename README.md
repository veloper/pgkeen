# pgkeen

pgkeen (`/ˈpiː‿ˈdʒiː.ˈkiːn/`) extends the official `postgres:16` docker image with essential extensions for AI/ML, vector operations, and data processing. It's built as a force multiplier for AI-function-calling tools like MCP, Dify, Flowise, etc, to enable a set of fundamental tools that can compose higher order functionality.

## Features

### Declarative ENV → PostgreSQL GUC Synchronization

Every 5 minutes, `pgkeen` uses the `pg_cron` and `getenv` extensions to automatically synchronize PostgreSQL settings (GUCs) with environment variables.

Here's how it works:
1.  The `pg_settings` view is queried, and the list of settings is filtered to exclude the following...
    *   Settings that are internal-use only (`vartype = 'internal'`) 
    *   Session-specific settings (`name LIKE 'local%'` or `'session%'`) 
    *   Settings that require a full server restart (`context = 'postmaster'`)
2.  For the remaining settings, a corresponding environment variable name is generated.
    *   `env_var = CONCAT('PG_', UPPER(REPLACE(name, '.', '__')))`
3.  Then, the values of these environment variables are retrieved.
4.  If a setting's current value in the database differs from its corresponding environment variable, an `ALTER SYSTEM` command is generated for it.
5.  Finally, `pg_reload_conf()` is called to atomically apply all staged changes to the live configuration.

#### Naming Convention Examples

| PostgreSQL GUC                  | Environment Variable                |
|:--------------------------------|:------------------------------------|
| `work_mem`                      | `PG_WORK_MEM`                       |
| `log_min_duration_statement`    | `PG_LOG_MIN_DURATION_STATEMENT`     |
| `auto_explain.log_min_duration` | `PG_AUTO_EXPLAIN__LOG_MIN_DURATION` |

> [!tip]
> Reset a GUC back to its default value by setting its environment variable to an empty string (`""`).

> [!note]
> These changes are persistent across process, container, and system restarts, as `ALTER SYSTEM` writes them to the `postgresql.auto.conf` file within your `$PGDATA` volume.

## Extensions

### AI, ML, and Vector Operations

| Extension | Description |
|-----------|-------------|
| [pgvector](https://github.com/pgvector/pgvector) | Open-source vector similarity search with support for exact and approximate nearest neighbor search |
| [pg_embedding](https://github.com/neondatabase/pg_embedding) | Hierarchical Navigable Small World (HNSW) algorithm for high-performance vector similarity search |
| [postgresml](https://github.com/postgresml/postgresml) | Machine learning extension that enables training and inference on text and tabular data using SQL |
| [pg_vectorize](https://github.com/tembo-io/pg_vectorize) | Automates text-to-embeddings transformation and provides hooks into popular LLMs for AI workloads |


### Utilities / System Tools

| Extension | Description |
|-----------|-------------|
| [pg_partman](https://github.com/pgpartman/pg_partman) | Automated partition management for time-based and serial-based table partitioning |
| [pg_cron](https://github.com/citusdata/pg_cron) | Simple cron-based job scheduler that runs inside the database as an extension |
| [pgmq](https://github.com/tembo-io/pgmq) | Lightweight message queue built on PostgreSQL for reliable async message processing |
| [pgsql-http](https://github.com/pramsey/pgsql-http) | HTTP client for PostgreSQL that allows making HTTP requests from SQL |
| [pg_net](https://github.com/supabase/pg_net) | Async networking interface for PostgreSQL that enables making HTTP requests and handling webhooks |
| [jsonschema](https://github.com/supabase/pg_jsonschema) | JSON Schema validation for PostgreSQL that validates JSON data against schemas |
| [pg_hashids](https://github.com/iCyberon/pg_hashids) | Generate short, unique, non-sequential ids from numbers using the Hashids algorithm |
| [envvar](https://github.com/theory/pg-envvar) | Functions for reading environment variables from within PostgreSQL sessions |

### Core Extensions 

All are pre-enabled on the `postgres` database via `CREATE EXTENSION` on image initialization.

| Extension | Description |
|-----------|-------------|
| [hstore](https://www.postgresql.org/docs/16/hstore.html) | Key-value store data type for storing sets of key/value pairs within a single PostgreSQL value |
| [ltree](https://www.postgresql.org/docs/16/ltree.html) | Hierarchical tree-like structures representation with operations for searching and manipulation |
| [citext](https://www.postgresql.org/docs/16/citext.html) | Case-insensitive character string type that behaves like text but ignores case in comparisons |
| [bloom](https://www.postgresql.org/docs/16/bloom.html) | Index access method based on Bloom filters for equality queries on multiple columns |
| [intarray](https://www.postgresql.org/docs/16/intarray.html) | Functions and operators for manipulating arrays of integers with GiST indexing support |
| [pg_trgm](https://www.postgresql.org/docs/16/pgtrgm.html) | Trigram matching for fast similarity searching and fuzzy string matching |
| [dict_int](https://www.postgresql.org/docs/16/dict-int.html) | Text search dictionary template for integers with customizable formatting |
| [fuzzystrmatch](https://www.postgresql.org/docs/16/fuzzystrmatch.html) | Functions for determining similarities and distance between strings using various algorithms |
| [uuid-ossp](https://www.postgresql.org/docs/16/uuid-ossp.html) | Functions for generating universally unique identifiers (UUIDs) using standard algorithms |
| [xml2](https://www.postgresql.org/docs/16/xml2.html) | XPath querying and XSLT processing functions for XML data manipulation |
| [autoinc](https://www.postgresql.org/docs/16/contrib-spi.html#AUTOINC) | Functions for autoincrementing fields and automatic sequence management |
| [intagg](https://www.postgresql.org/docs/16/intagg.html) | Integer aggregator and enumerator functions for working with integer collections |
| [plpython3u](https://www.postgresql.org/docs/16/plpython.html) | Procedural language that allows writing PostgreSQL functions and procedures in Python |

### Misc

| Extension | Description |
|-----------|-------------|
| [Apache AGE](https://github.com/apache/age) | A graph database extension that allows leveraging graph database functionality on top of PostgreSQL |
| [PostGIS](https://github.com/postgis/postgis) | Spatial database extender that adds support for geographic objects and spatial queries |


## Additional Features
- Python 3.10.14 compiled from source
- All extensions pre-installed and enabled on `postgres` database and user.
- Full carryover support for the official `postgres:16` image and its idiosyncrasies.
- Custom python scripts that provide targeted `postgresql.conf` editing as well as initdb creation. 



> [!note]
> This convention is identical to how `pydantic-settings` translates environment variables into nested models.

## Usage


### From `Dockerfile`

```bash
# Run with default settings
docker run -d --name pgkeen -e POSTGRES_PASSWORD=$YOUR_PASSWORD -p 5432:5432  -v data:/var/lib/postgresql/data veloper/pgkeen:latest
```

### From `docker-compose.yml`
```bash

POSTGRES_PASSWORD=$YOUR_PASSWORD POSTGRES_HOST_AUTH_METHOD=$YOUR_AUTH_METHOD docker-compose up
```


```yaml
services:
  db:
    restart: always
    image: pgkeen:latest 
    command: postgres -c config_file=/var/lib/postgresql/data/postgresql.conf
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD:-}"
      POSTGRES_HOST_AUTH_METHOD: "${POSTGRES_HOST_AUTH_METHOD:-trust}"
      PGDATA: /var/lib/postgresql/data


      # Declarative ENV => GUCs 
      PG_AUTOINC:
    ports:
      - "5432:5432"
    networks:
      shared_default:
        aliases:
          - postgres # alias so other services can connect using a more explicit name
    volumes:
      - ./data:/var/lib/postgresql/data
networks:
  shared_default:
    driver: bridge
    # Uncomment if you want to launch just this service, and allow other 
    # networks to access it (requires the external network to be created 
    # beforehand)
    # external: true 
```

## Configuration

All of the documentation for the official `postgres:16` image still hold true so consult the [PostgreSQL Docker Hub README](https://hub.docker.com/_/postgres) for extensive details on the available configuration options.

## Contributing
Contributions are welcome! If you have ideas for improvements, bug fixes, or new features, please follow these steps:

1. Fork this repository.
2. Create a feature branch for your changes.
3. Ensure your code follows project conventions and passes all tests.
4. Submit a pull request with a clear description of your changes and reference any related issues.
5. For bugs or feature requests, please open an issue first to discuss your ideas.

Always use the golden-rule of open source contributions:

> "If I were the maintainer, how would I want to receive this pull request?"

## License
Simple 3-BSD License. See the [LICENSE](LICENSE) file for details.