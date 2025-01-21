# PostgreSQL Configuration Guide for PGai

## Configuration File Locations

On this macOS system (using Homebrew):

1. **Data Directory**:
   ```
   /opt/homebrew/var/postgresql@15
   ```

2. **Main Configuration Files**:
   - postgresql.conf: `/opt/homebrew/var/postgresql@15/postgresql.conf`
   - pg_hba.conf: `/opt/homebrew/var/postgresql@15/pg_hba.conf`
   - pg_ident.conf: `/opt/homebrew/var/postgresql@15/pg_ident.conf`

3. **Runtime Configuration**:
   - System-wide settings are stored in `postgresql.conf`
   - User authentication rules are in `pg_hba.conf`
   - User name mappings are in `pg_ident.conf`

## Important Configuration Parameters

Parameters that PGai monitors and may suggest adjustments for:

1. **Memory Settings**:
   ```
   shared_buffers = 128MB        # Adjust based on system memory
   work_mem = 4MB               # Per-operation memory
   maintenance_work_mem = 64MB  # For maintenance operations
   effective_cache_size = 4GB   # Estimate of system memory available
   ```

2. **Connection Settings**:
   ```
   max_connections = 100        # Maximum concurrent connections
   ```

3. **Query Parallelism**:
   ```
   max_worker_processes = 8
   max_parallel_workers = 8
   max_parallel_workers_per_gather = 2
   ```

4. **I/O Settings**:
   ```
   effective_io_concurrency = 1    # Concurrent I/O operations
   random_page_cost = 4.0         # Cost of non-sequential page fetches
   ```

## Modifying Configuration

### Method 1: Direct File Edit
1. Edit the configuration file:
   ```bash
   sudo vim /opt/homebrew/var/postgresql@15/postgresql.conf
   ```
2. Reload PostgreSQL:
   ```bash
   brew services restart postgresql@15
   ```

### Method 2: SQL Commands
1. View current settings:
   ```sql
   SHOW [parameter_name];
   ```
2. Modify settings:
   ```sql
   ALTER SYSTEM SET parameter_name = 'value';
   ```
3. Reload configuration:
   ```sql
   SELECT pg_reload_conf();
   ```

### Method 3: Using PGai
1. Use the dashboard interface to view current settings
2. Apply recommended changes through the UI
3. PGai will execute the necessary ALTER SYSTEM commands

## Configuration Backup

1. Backup configuration files:
   ```bash
   cp /opt/homebrew/var/postgresql@15/postgresql.conf /opt/homebrew/var/postgresql@15/postgresql.conf.backup
   cp /opt/homebrew/var/postgresql@15/pg_hba.conf /opt/homebrew/var/postgresql@15/pg_hba.conf.backup
   ```

2. Restore if needed:
   ```bash
   cp /opt/homebrew/var/postgresql@15/postgresql.conf.backup /opt/homebrew/var/postgresql@15/postgresql.conf
   cp /opt/homebrew/var/postgresql@15/pg_hba.conf.backup /opt/homebrew/var/postgresql@15/pg_hba.conf
   ```

## Configuration History

PGai maintains a history of configuration changes in:
1. The `configHistory` array in memory
2. The metrics database for correlation with performance metrics

## Best Practices

1. **Always backup configuration** before making changes
2. **Test changes in staging** before applying to production
3. **Monitor effects** of configuration changes using PGai dashboard
4. **Document changes** and their impact
5. **Keep track of default values** for reference

## Troubleshooting

1. If PostgreSQL won't start:
   ```bash
   tail -f /opt/homebrew/var/log/postgresql@15.log
   ```

2. Check configuration syntax:
   ```bash
   /opt/homebrew/opt/postgresql@15/bin/postgres -D /opt/homebrew/var/postgresql@15 -C config_file
   ```

3. View effective configuration:
   ```sql
   SELECT name, setting, unit, context 
   FROM pg_settings 
   ORDER BY name;
   ```

## Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/15/runtime-config.html)
- [PostgreSQL Wiki - Tuning](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
- [PGai Documentation](../README.md)
