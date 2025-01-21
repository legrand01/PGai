# Adding Custom PostgreSQL Configuration on macOS

There are several ways to add custom configurations to PostgreSQL installed via Homebrew on macOS.

## Method 1: Using conf.d Directory

1. Create a conf.d directory in the PostgreSQL data directory:
```bash
mkdir -p /opt/homebrew/var/postgresql@15/conf.d
```

2. Create your custom configuration file (e.g., `custom.conf`):
```bash
vim /opt/homebrew/var/postgresql@15/conf.d/custom.conf
```

3. Add your custom settings, for example:
```
# Memory Configuration
shared_buffers = '256MB'
work_mem = '16MB'
maintenance_work_mem = '128MB'

# Query Planning
random_page_cost = 1.1
effective_cache_size = '1GB'

# Parallel Query
max_worker_processes = 8
max_parallel_workers_per_gather = 4
max_parallel_workers = 8
```

4. Add include directive to `postgresql.conf`:
```bash
echo "include_dir = 'conf.d'" >> /opt/homebrew/var/postgresql@15/postgresql.conf
```

## Method 2: Using postgresql.auto.conf

PostgreSQL automatically loads settings from `postgresql.auto.conf`, which is designed for programmatic modifications:

1. Use ALTER SYSTEM commands:
```sql
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET work_mem = '16MB';
```

These commands will write to `postgresql.auto.conf` automatically.

## Method 3: Environment Variables

For connection-related settings, you can use environment variables:

1. Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):
```bash
export PGHOST=localhost
export PGPORT=5432
export PGDATA=/opt/homebrew/var/postgresql@15
```

## Applying Changes

After making configuration changes:

1. Check configuration:
```bash
/opt/homebrew/opt/postgresql@15/bin/postgres -D /opt/homebrew/var/postgresql@15 -C config_file
```

2. Reload configuration (without restart):
```bash
brew services reload postgresql@15
# OR
pg_ctl reload -D /opt/homebrew/var/postgresql@15
```

3. Restart PostgreSQL (if needed):
```bash
brew services restart postgresql@15
```

## Configuration Precedence

PostgreSQL configuration parameters are loaded in this order:

1. Internal defaults
2. `postgresql.conf`
3. `postgresql.conf.d/*.conf` (if include_dir is set)
4. `postgresql.auto.conf` (for ALTER SYSTEM commands)
5. Command-line parameters
6. Environment variables (for connection parameters)

Later entries override earlier ones.

## Best Practices

1. **Organize by Function**
   Create separate conf files for different purposes:
   ```
   conf.d/
   ├── 00-memory.conf
   ├── 01-query-planning.conf
   ├── 02-replication.conf
   └── 03-logging.conf
   ```

2. **Version Control**
   Keep your custom configurations in version control:
   ```bash
   git init /opt/homebrew/var/postgresql@15/conf.d
   ```

3. **Documentation**
   Comment your configuration files:
   ```
   # Memory Configuration
   # Last updated: 2024-01-22
   # Purpose: Optimize for 16GB RAM system
   shared_buffers = '256MB'  # 25% of RAM for dedicated PostgreSQL memory
   ```

4. **Testing**
   Test configuration changes in a staging environment first:
   ```bash
   pg_ctl -D /path/to/test/data start -o "-c config_file=/path/to/test/postgresql.conf"
   ```

## Monitoring Configuration

1. View current settings:
```sql
SELECT name, setting, unit, context
FROM pg_settings
WHERE source != 'default'
ORDER BY name;
```

2. View configuration file location:
```sql
SHOW config_file;
```

3. Check included files:
```sql
SHOW include_dir;
SHOW include_if_exists;
```

## Troubleshooting

1. If PostgreSQL won't start after configuration changes:
   ```bash
   tail -f /opt/homebrew/var/log/postgresql@15.log
   ```

2. Reset problematic settings:
   ```sql
   ALTER SYSTEM RESET parameter_name;
   ```

3. Remove all ALTER SYSTEM changes:
   ```bash
   rm /opt/homebrew/var/postgresql@15/postgresql.auto.conf
   ```

## Using with PGai

PGai can manage these configuration files through its dashboard:

1. View current configuration
2. Apply recommended changes
3. Track configuration history
4. Monitor impact of changes

The dashboard will automatically use the appropriate method (ALTER SYSTEM or conf.d) based on the parameter being modified.
