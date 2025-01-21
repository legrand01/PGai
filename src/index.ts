#!/usr/bin/env node
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import express from 'express';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import pkg from 'pg';
const { Client } = pkg;
import * as si from 'systeminformation';
import { ConfigAnalyzer } from './config_analyzer.js';

interface PostgresSettings {
  name: string;
  setting: string;
  unit: string | null;
  context: string;
  vartype: string;
}

interface PostgresConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

interface MonitoringData {
  timestamp: number;
  metrics: {
    connections: number;
    activeQueries: number;
    cacheHitRatio: number;
    transactionsPerSec: number;
    avgQueryTime: number;
    memoryUsage: number;
    cpuUsage: number;
    iops: number;
  };
}

interface ConfigHistoryEntry {
  timestamp: number;
  config: Record<string, PostgresSettings>;
}

class PGaiServer {
  private server: Server;
  private pgClient: InstanceType<typeof Client> | null = null;
  private configAnalyzer: ConfigAnalyzer | null = null;
  private configHistory: ConfigHistoryEntry[] = [];

  constructor() {
    this.server = new Server(
      {
        name: 'PGai',
        version: '0.1.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    
    this.server.onerror = (error) => console.error('[MCP Error]', error);
    process.on('SIGINT', async () => {
      await this.cleanup();
      process.exit(0);
    });

    // Auto-connect using environment variables
    const config: PostgresConfig = {
      host: process.env.PGHOST || 'localhost',
      port: parseInt(process.env.PGPORT || '5432'),
      database: process.env.PGDATABASE || 'postgres',
      user: process.env.PGUSER || 'postgres',
      password: process.env.PGPASSWORD || ''
    };

    this.pgClient = new Client(config);
    this.pgClient.connect().then(async () => {
      // Get total system memory for the config analyzer
      const memInfo = await si.mem();
      const totalMemoryMB = Math.floor(memInfo.total / (1024 * 1024));
      this.configAnalyzer = new ConfigAnalyzer(this.pgClient!, totalMemoryMB);
    }).catch((error: any) => {
      console.error('Failed to auto-connect:', error);
      process.exit(1);
    });
  }

  private setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'connect_database',
          description: 'Connect to a PostgreSQL database',
          inputSchema: {
            type: 'object',
            properties: {
              host: { type: 'string', description: 'Database host' },
              port: { type: 'number', description: 'Database port' },
              database: { type: 'string', description: 'Database name' },
              user: { type: 'string', description: 'Database user' },
              password: { type: 'string', description: 'Database password' }
            },
            required: ['host', 'port', 'database', 'user', 'password']
          }
        },
        {
          name: 'get_performance_metrics',
          description: 'Get current database performance metrics',
          inputSchema: {
            type: 'object',
            properties: {},
            required: []
          }
        },
        {
          name: 'analyze_performance',
          description: 'Analyze database performance and get AI-powered recommendations',
          inputSchema: {
            type: 'object',
            properties: {
              timeRange: { 
                type: 'string', 
                description: 'Time range in minutes for analysis (e.g. "30" or "60")'
              }
            },
            required: ['timeRange']
          }
        },
        {
          name: 'update_config',
          description: 'Update database configuration parameters',
          inputSchema: {
            type: 'object',
            properties: {
              parameters: {
                type: 'object',
                description: 'Configuration parameters to update',
                additionalProperties: true
              }
            },
            required: ['parameters']
          }
        },
        {
          name: 'get_config',
          description: 'Get current database configuration',
          inputSchema: {
            type: 'object',
            properties: {},
            required: []
          }
        }
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      switch (request.params.name) {
        case 'connect_database':
          return await this.handleConnectDatabase(request.params.arguments ?? {});
        case 'get_performance_metrics':
          return await this.handleGetPerformanceMetrics();
        case 'analyze_performance':
          return await this.handleAnalyzePerformance(request.params.arguments ?? {});
        case 'update_config':
          return await this.handleUpdateConfig(request.params.arguments ?? {});
        case 'get_config':
          return await this.handleGetConfig();
        default:
          throw new McpError(
            ErrorCode.MethodNotFound,
            `Unknown tool: ${request.params.name}`
          );
      }
    });
  }

  private async handleConnectDatabase(args: Record<string, unknown>) {
    try {
      const config: PostgresConfig = {
        host: String(args.host),
        port: Number(args.port),
        database: String(args.database),
        user: String(args.user),
        password: String(args.password)
      };

      if (this.pgClient) {
        await this.pgClient.end();
      }

      this.pgClient = new Client(config);
      await this.pgClient.connect();

      // Initialize config analyzer with new connection
      const memInfo = await si.mem();
      const totalMemoryMB = Math.floor(memInfo.total / (1024 * 1024));
      this.configAnalyzer = new ConfigAnalyzer(this.pgClient, totalMemoryMB);

      return {
        content: [
          {
            type: 'text',
            text: 'Successfully connected to database'
          }
        ]
      };
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to connect to database: ${errorMessage}`
      );
    }
  }

  private async handleGetPerformanceMetrics() {
    if (!this.pgClient) {
      throw new McpError(
        ErrorCode.InvalidRequest,
        'Not connected to database. Call connect_database first.'
      );
    }

    try {
      // Get database metrics
      const results = await Promise.all([
        this.pgClient.query('SELECT count(*) FROM pg_stat_activity'),
        this.pgClient.query(`
          SELECT (sum(xact_commit) + sum(xact_rollback))::float8 / 
                 (extract(epoch from now() - min(stats_reset))) as tps
          FROM pg_stat_database
          WHERE datname = current_database()
        `),
        this.pgClient.query(`
          SELECT sum(blks_hit)::float8 / (sum(blks_hit) + sum(blks_read)) as cache_hit_ratio
          FROM pg_stat_database
          WHERE datname = current_database()
        `),
        si.currentLoad(),
        si.mem(),
        si.disksIO()
      ]);

      const metrics: MonitoringData = {
        timestamp: Date.now(),
        metrics: {
          connections: parseInt(results[0].rows[0].count),
          transactionsPerSec: parseFloat(results[1].rows[0].tps),
          cacheHitRatio: parseFloat(results[2].rows[0].cache_hit_ratio),
          cpuUsage: results[3].currentLoad,
          memoryUsage: (results[4].active / results[4].total) * 100,
          iops: results[5].rIO + results[5].wIO,
          activeQueries: 0, // Placeholder
          avgQueryTime: 0 // Placeholder
        }
      };

      // Store metrics in database
      await this.pgClient.query(
        `INSERT INTO metrics_history.metrics (
          timestamp, connections, transactions_per_sec, cache_hit_ratio,
          cpu_usage, memory_usage, iops, active_queries, avg_query_time
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
        [
          new Date(metrics.timestamp),
          metrics.metrics.connections,
          metrics.metrics.transactionsPerSec,
          metrics.metrics.cacheHitRatio,
          metrics.metrics.cpuUsage,
          metrics.metrics.memoryUsage,
          metrics.metrics.iops,
          metrics.metrics.activeQueries,
          metrics.metrics.avgQueryTime
        ]
      );

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(metrics, null, 2)
          }
        ]
      };
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to get performance metrics: ${errorMessage}`
      );
    }
  }

  private async handleAnalyzePerformance(args: Record<string, unknown>) {
    if (!this.pgClient || !this.configAnalyzer) {
      throw new McpError(
        ErrorCode.InvalidRequest,
        'Not connected to database. Call connect_database first.'
      );
    }

    try {
      const timeRangeMinutes = parseInt(String(args.timeRange));
      if (isNaN(timeRangeMinutes) || timeRangeMinutes <= 0) {
        throw new Error('Invalid time range. Please provide a positive number of minutes.');
      }

      // Get current settings
      const currentSettings = await this.configAnalyzer.getCurrentSettings();
      
      // Get recommendations based on metrics
      const recommendations = await this.configAnalyzer.analyzeMetrics(timeRangeMinutes);

      // Format recommendations with current values
      const formattedRecommendations = recommendations.map(rec => ({
        ...rec,
        currentValue: currentSettings[rec.parameter] || 'unknown'
      }));

      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify({
              timeRange: `${timeRangeMinutes} minutes`,
              recommendations: formattedRecommendations
            }, null, 2)
          }
        ]
      };
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to analyze performance: ${errorMessage}`
      );
    }
  }

  private async handleUpdateConfig(args: Record<string, unknown>) {
    if (!this.pgClient) {
      throw new McpError(
        ErrorCode.InvalidRequest,
        'Not connected to database. Call connect_database first.'
      );
    }

    try {
      const parameters = args.parameters as Record<string, unknown>;
      // Validate parameters
      const validParameters = await this.validateParameters(parameters);
      
      // Store current config for history
      const currentConfig = await this.getCurrentConfig();
      this.configHistory.push({
        timestamp: Date.now(),
        config: currentConfig
      });

      // Apply changes
      for (const [key, value] of Object.entries(validParameters)) {
        await this.pgClient.query(`ALTER SYSTEM SET ${key} = ${value}`);
      }

      return {
        content: [
          {
            type: 'text',
            text: `Successfully updated configuration parameters: ${Object.keys(validParameters).join(', ')}`
          }
        ]
      };
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to update configuration: ${errorMessage}`
      );
    }
  }

  private async handleGetConfig() {
    if (!this.pgClient) {
      throw new McpError(
        ErrorCode.InvalidRequest,
        'Not connected to database. Call connect_database first.'
      );
    }

    try {
      const config = await this.getCurrentConfig();
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(config, null, 2)
          }
        ]
      };
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred';
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to get configuration: ${errorMessage}`
      );
    }
  }

  private async getCurrentConfig(): Promise<Record<string, PostgresSettings>> {
    const result = await this.pgClient!.query<PostgresSettings>(`
      SELECT name, setting, unit, context, vartype
      FROM pg_settings
      WHERE name IN (
        'work_mem',
        'random_page_cost',
        'seq_page_cost',
        'effective_io_concurrency',
        'max_parallel_workers_per_gather',
        'max_parallel_workers',
        'max_worker_processes',
        'min_wal_size',
        'max_wal_size',
        'checkpoint_completion_target',
        'bgwriter_lru_maxpages',
        'bgwriter_delay'
      )
    `);
    
    return result.rows.reduce<Record<string, PostgresSettings>>((acc: Record<string, PostgresSettings>, row: PostgresSettings) => {
      acc[row.name] = row;
      return acc;
    }, {});
  }

  private async validateParameters(parameters: Record<string, unknown>): Promise<Record<string, unknown>> {
    const validParameters: Record<string, unknown> = {};
    
    for (const [key, value] of Object.entries(parameters)) {
      // Check if parameter exists
      const result = await this.pgClient!.query(
        'SELECT name FROM pg_settings WHERE name = $1',
        [key]
      );
      
      if (result.rows.length === 0) {
        throw new Error(`Invalid parameter: ${key}`);
      }

      // Add basic validation here
      // Could be expanded based on parameter types and valid ranges
      validParameters[key] = value;
    }

    return validParameters;
  }

  private async cleanup() {
    if (this.pgClient) {
      await this.pgClient.end();
    }
    await this.server.close();
  }

  async run() {
    // Set up MCP server with stdio transport
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('PGai MCP server running on stdio');

    // Set up HTTP server for dashboard
    const app = express();
    app.use(express.json());

    // Handle MCP tool calls via HTTP
    app.post('/mcp', async (req, res) => {
      try {
        const { method, params } = req.body;
        
        switch (method) {
          case 'callTool': {
            const { name, arguments: args } = params;
            switch (name) {
              case 'get_performance_metrics':
                return res.json(await this.handleGetPerformanceMetrics());
              case 'analyze_performance':
                return res.json(await this.handleAnalyzePerformance(args ?? {}));
              case 'get_config':
                return res.json(await this.handleGetConfig());
              case 'update_config':
                return res.json(await this.handleUpdateConfig(args ?? {}));
              case 'connect_database':
                return res.json(await this.handleConnectDatabase(args ?? {}));
              default:
                throw new Error(`Unknown tool: ${name}`);
            }
          }
          case 'listTools': {
            const tools = [
              {
                name: 'connect_database',
                description: 'Connect to a PostgreSQL database',
                inputSchema: {
                  type: 'object',
                  properties: {
                    host: { type: 'string', description: 'Database host' },
                    port: { type: 'number', description: 'Database port' },
                    database: { type: 'string', description: 'Database name' },
                    user: { type: 'string', description: 'Database user' },
                    password: { type: 'string', description: 'Database password' }
                  },
                  required: ['host', 'port', 'database', 'user', 'password']
                }
              },
              {
                name: 'get_performance_metrics',
                description: 'Get current database performance metrics',
                inputSchema: {
                  type: 'object',
                  properties: {},
                  required: []
                }
              },
              {
                name: 'analyze_performance',
                description: 'Analyze database performance and get AI-powered recommendations',
                inputSchema: {
                  type: 'object',
                  properties: {
                    timeRange: { 
                      type: 'string', 
                      description: 'Time range in minutes for analysis (e.g. "30" or "60")'
                    }
                  },
                  required: ['timeRange']
                }
              },
              {
                name: 'update_config',
                description: 'Update database configuration parameters',
                inputSchema: {
                  type: 'object',
                  properties: {
                    parameters: {
                      type: 'object',
                      description: 'Configuration parameters to update',
                      additionalProperties: true
                    }
                  },
                  required: ['parameters']
                }
              },
              {
                name: 'get_config',
                description: 'Get current database configuration',
                inputSchema: {
                  type: 'object',
                  properties: {},
                  required: []
                }
              }
            ];
            return res.json({ tools });
          }
          default:
            throw new Error(`Unknown method: ${method}`);
        }
      } catch (error) {
        console.error('Error handling MCP request:', error);
        res.status(500).json({ error: error instanceof Error ? error.message : 'Internal server error' });
      }
    });

    // Start HTTP server
    app.listen(3001, () => {
      console.error('HTTP server running on http://localhost:3001');
    });

    // Log connection details
    console.error('Database connection config:', {
      host: process.env.PGHOST,
      port: process.env.PGPORT,
      database: process.env.PGDATABASE,
      user: process.env.PGUSER
    });
  }
}

const server = new PGaiServer();
server.run().catch(console.error);
