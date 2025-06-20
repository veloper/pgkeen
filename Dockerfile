FROM postgres:16

# Install dependencies, Rust, and pg-trunk in single layer with aggressive cleanup
RUN apt-get update && apt-get install -y \
    # Basic system tools
    curl \
    gnupg \
    lsb-release \
    git \
    # Build dependencies (removed after extension installation)
    build-essential \
    pkg-config \
    cmake \
    # PostgreSQL development
    postgresql-server-dev-16 \
    # Python development
    python3-dev \
    python3-pip \
    python3-psycopg2 \
    python3-click \
    # Kerberos support
    libkrb5-dev \
    # Runtime libraries for extensions (kept permanently)
    libc6-dev \
    libcurl4 \
    libgcc-s1 \
    libgdal-dev \
    libgeos-c1v5 \
    libgomp1 \
    libjson-c5 \
    libopenblas0-pthread \
    libpcre2-8-0 \
    libpq5 \
    libproj-dev \
    libprotobuf-c1 \
    libstdc++6 \
    libuuid1 \
    libxml2 && \
    # Install Rust
    curl https://sh.rustup.rs -sSf | sh -s -- -y && \
    export PATH="/root/.cargo/bin:${PATH}" && \
    # Install pg-trunk 
    cargo install pg-trunk && \
    # Minimal cleanup in same layer (full cleanup after extensions)
    rm -rf /root/.cargo/registry/* && \
    rm -rf /root/.cargo/git/* && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*

# Set the PATH environment variable to include Cargo's bin directory
ENV PATH="/root/.cargo/bin:${PATH}"

# ===============================================================================================
# Install Python 3.10.14 so we can use pg extensions 
# ===============================================================================================

RUN apt-get update && \
    apt-get install -y wget libssl-dev zlib1g-dev \
    libncurses5-dev libncursesw5-dev libreadline-dev libsqlite3-dev \
    libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev tk-dev && \
    wget https://www.python.org/ftp/python/3.10.14/Python-3.10.14.tgz && \
    tar -xzf Python-3.10.14.tgz && \
    cd Python-3.10.14 && \
    ./configure --enable-optimizations --enable-shared && \
    make -j$(nproc) && \
    make altinstall && \
    cd .. && \
    rm -rf Python-3.10.14 Python-3.10.14.tgz && \
    # Remove Python build dependencies in same layer
    apt-get remove --purge -y wget libssl-dev zlib1g-dev \
    libncurses5-dev libncursesw5-dev libreadline-dev libsqlite3-dev \
    libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev tk-dev && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*


# ================================================================================================
# Install `sudo` pass-through (req: for trunk install--deps option)
# ===============================================================================================

COPY ./docker/sudo.sh /usr/local/bin/sudo
RUN chmod +x /usr/local/bin/sudo
    
# ===============================================================================================
# Install pg_tools.py and trunk-install.py
# ===============================================================================================

RUN apt-get update && \
    apt-get install -y python3-psycopg2 python3-click && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./docker/pg_tools.py /usr/local/bin/pg_tools.py
RUN chmod +x /usr/local/bin/pg_tools.py

COPY docker/trunk-install.py /usr/local/bin/trunk-install
RUN chmod +x /usr/local/bin/trunk-install

# ===============================================================================================
# Install all extensions in single layer
# ===============================================================================================

RUN trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pgvector && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib age && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pg_partman && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pg_trgm && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pgsql_http && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib plpython3u && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pg_net && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pg_jsonschema && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib hstore && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib ltree && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib dict_int && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib intarray && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib intagg && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib fuzzystrmatch && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib bloom && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib uuid_ossp && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib xml2 && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pg_hashids && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib autoinc && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib postgis && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib citext && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pg_embedding && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib postgresml && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib vectorize && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib pgmq && \
    trunk install --pg-config /usr/lib/postgresql/16/bin/pg_config --pg-version 16 --sharedir /usr/share/postgresql/16 --pkglibdir /usr/lib/postgresql/16/lib envvar && \
    # COMPLETE CLEANUP: Remove entire Rust toolchain and build tools after extensions installed
    rm -rf /root/.rustup && \
    rm -rf /root/.cargo && \
    apt-get remove --purge -y build-essential cmake pkg-config && \
    apt-get autoremove -y && \
    rm -rf ~/.pg-trunk/cache || true && \
    rm -rf /tmp/* || true

# ===================================================================================================
# pg_tools.py // INITDB 
# ===================================================================================================

RUN <<EOF_INITDB

START=$(date +%s%N)
uid() { 
    local NOW=$(date +%s%N)
    local DIFF=$(($NOW - $START))
    printf "%015d" $DIFF
}


# Modify PostgreSQL configuration through a shell command
# Note: Manually extracted form trunk installation logs
pg_tools.py initdb upsert "$(uid)_postgresql_conf_shared_preload_libraries" sh "pg_tools.py conf upsert shared_preload_libraries age pg_net pgml pg_cron vectorize"

# Cron Required Settings
pg_tools.py initdb upsert "$(uid)_postgresql_conf_cron_db_name" sh "pg_tools.py conf upsert cron.database_name postgres"

# Setup the postgres role (ensure it exists and has correct privileges)
pg_tools.py initdb upsert "$(uid)_postgres_role" sql "ALTER ROLE postgres LOGIN SUPERUSER;"
pg_tools.py initdb upsert "$(uid)_postgres_grant_db_privileges" sql "GRANT ALL PRIVILEGES ON DATABASE postgres TO postgres;"

# Enable all extensions for the 'postgres' database
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS vector CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS age CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pg_partman CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pg_trgm CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS http CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS plpython3u CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pg_net CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pg_jsonschema CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS hstore CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS ltree CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS dict_int CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS intarray CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS intagg CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS fuzzystrmatch CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS bloom CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS uuid-ossp CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS xml2 CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pg_hashids CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS autoinc CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS citext CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS embedding CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pgml CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pg_cron CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS pgmq CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS vectorize CASCADE;\""
pg_tools.py initdb upsert "$(uid)_create_ext_on_postgres" sh "psql -d postgres -c \"CREATE EXTENSION IF NOT EXISTS envvar CASCADE;\""
EOF_INITDB

# Default command - entrypoint handles config location and execution
CMD ["postgres"]