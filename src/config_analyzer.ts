import { Client } from 'pg';

interface MetricsSummary {
  avgCpuUsage: number;
  avgMemoryUsage: number;
  avgIops: number;
  avgConnections: number;
  avgCacheHitRatio: number;
  avgQueryTime: number;
  maxParallelQueries: number;
  totalMemoryMB: number;
}

interface ConfigRecommendation {
  parameter: string;
  currentValue: string;
  recommendedValue: string;
  reasoning: string;
  impact: 'high' | 'medium' | 'low';
  requiresRestart: boolean;
}

export class ConfigAnalyzer {
  private pgClient: Client;
  private totalMemoryMB: number;

  constructor(pgClient: Client, totalMemoryMB: number) {
    this.pgClient = pgClient;
    this.totalMemoryMB = totalMemoryMB;
  }

  async analyzeMetrics(timeRangeMinutes: number): Promise<ConfigRecommendation[]> {
    const metrics = await this.getMetricsSummary(timeRangeMinutes);
    return this.generateRecommendations(metrics);
  }

  private async getMetricsSummary(timeRangeMinutes: number): Promise<MetricsSummary> {
    const result = await this.pgClient.query(`
      SELECT
        round(avg(cpu_usage)::numeric, 2) as avg_cpu_usage,
        round(avg(memory_usage)::numeric, 2) as avg_memory_usage,
        round(avg(iops)::numeric, 2) as avg_iops,
        round(avg(connections)::numeric, 2) as avg_connections,
        round(avg(cache_hit_ratio)::numeric, 4) as avg_cache_hit_ratio,
        round(avg(avg_query_time)::numeric, 4) as avg_query_time,
        round(max(active_queries)::numeric, 2) as max_parallel_queries
      FROM metrics_history.metrics
      WHERE timestamp > NOW() - interval '${timeRangeMinutes} minutes'
    `);

    return {
      avgCpuUsage: parseFloat(result.rows[0].avg_cpu_usage),
      avgMemoryUsage: parseFloat(result.rows[0].avg_memory_usage),
      avgIops: parseFloat(result.rows[0].avg_iops),
      avgConnections: parseFloat(result.rows[0].avg_connections),
      avgCacheHitRatio: parseFloat(result.rows[0].avg_cache_hit_ratio),
      avgQueryTime: parseFloat(result.rows[0].avg_query_time),
      maxParallelQueries: parseFloat(result.rows[0].max_parallel_queries),
      totalMemoryMB: this.totalMemoryMB
    };
  }

  private generateRecommendations(metrics: MetricsSummary): ConfigRecommendation[] {
    const recommendations: ConfigRecommendation[] = [];

    // work_mem recommendation
    const avgMemoryPerConnection = (metrics.totalMemoryMB * 0.25) / Math.max(metrics.avgConnections, 1);
    recommendations.push({
      parameter: 'work_mem',
      currentValue: 'default',
      recommendedValue: `${Math.floor(avgMemoryPerConnection)}MB`,
      reasoning: `Based on average ${metrics.avgConnections} concurrent connections and ${metrics.totalMemoryMB}MB total memory. Allocates 25% of memory for work_mem across all connections.`,
      impact: 'high',
      requiresRestart: false
    });

    // random_page_cost and seq_page_cost recommendations
    if (metrics.avgIops > 1000) { // High IOPS indicates good I/O performance
      recommendations.push({
        parameter: 'random_page_cost',
        currentValue: 'default',
        recommendedValue: '1.1',
        reasoning: `High I/O performance (${metrics.avgIops} IOPS) suggests random reads are nearly as efficient as sequential reads.`,
        impact: 'medium',
        requiresRestart: false
      });
    }

    // effective_io_concurrency recommendation
    const recommendedIoConcurrency = Math.min(Math.floor(metrics.avgIops / 200), 32);
    recommendations.push({
      parameter: 'effective_io_concurrency',
      currentValue: 'default',
      recommendedValue: recommendedIoConcurrency.toString(),
      reasoning: `Based on observed ${metrics.avgIops} IOPS. Allows PostgreSQL to issue this many concurrent I/O operations.`,
      impact: 'medium',
      requiresRestart: false
    });

    // Parallel query worker recommendations
    const cpuCores = Math.floor(metrics.avgCpuUsage / 100);
    if (cpuCores > 2) {
      recommendations.push({
        parameter: 'max_parallel_workers_per_gather',
        currentValue: 'default',
        recommendedValue: Math.min(cpuCores - 1, 4).toString(),
        reasoning: `System has ${cpuCores} CPU cores. Reserving one core for the leader process.`,
        impact: 'high',
        requiresRestart: false
      });

      recommendations.push({
        parameter: 'max_parallel_workers',
        currentValue: 'default',
        recommendedValue: Math.min(cpuCores * 2, 16).toString(),
        reasoning: `Based on ${cpuCores} CPU cores. Allows multiple parallel operations while preventing CPU oversaturation.`,
        impact: 'high',
        requiresRestart: false
      });

      recommendations.push({
        parameter: 'max_worker_processes',
        currentValue: 'default',
        recommendedValue: Math.min(cpuCores * 2, 16).toString(),
        reasoning: `Matches max_parallel_workers to ensure sufficient worker processes are available.`,
        impact: 'high',
        requiresRestart: true
      });
    }

    // WAL recommendations based on memory and IOPS
    const totalWalSizeMB = Math.min(metrics.totalMemoryMB * 0.1, 1024);
    recommendations.push({
      parameter: 'min_wal_size',
      currentValue: 'default',
      recommendedValue: `${Math.floor(totalWalSizeMB / 4)}MB`,
      reasoning: `Set to 1/4 of max_wal_size to prevent frequent WAL file recycling.`,
      impact: 'medium',
      requiresRestart: false
    });

    recommendations.push({
      parameter: 'max_wal_size',
      currentValue: 'default',
      recommendedValue: `${Math.floor(totalWalSizeMB)}MB`,
      reasoning: `Based on system memory (${metrics.totalMemoryMB}MB). Balances checkpoint frequency with storage usage.`,
      impact: 'medium',
      requiresRestart: false
    });

    // Checkpoint and background writer tuning
    if (metrics.avgIops > 1000) {
      recommendations.push({
        parameter: 'checkpoint_completion_target',
        currentValue: 'default',
        recommendedValue: '0.9',
        reasoning: `High I/O capacity (${metrics.avgIops} IOPS) allows spreading checkpoints over more time.`,
        impact: 'medium',
        requiresRestart: false
      });

      const bgwriterMaxpages = Math.floor(metrics.avgIops / 2);
      recommendations.push({
        parameter: 'bgwriter_lru_maxpages',
        currentValue: 'default',
        recommendedValue: bgwriterMaxpages.toString(),
        reasoning: `Based on observed ${metrics.avgIops} IOPS. Allows background writer to keep up with high I/O capacity.`,
        impact: 'medium',
        requiresRestart: false
      });

      recommendations.push({
        parameter: 'bgwriter_delay',
        currentValue: 'default',
        recommendedValue: '200ms',
        reasoning: `High I/O capacity allows more frequent background writer activity.`,
        impact: 'low',
        requiresRestart: false
      });
    }

    return recommendations;
  }

  async getCurrentSettings(): Promise<Record<string, string>> {
    const result = await this.pgClient.query(`
      SELECT name, setting, unit
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

    return result.rows.reduce((acc: Record<string, string>, row) => {
      acc[row.name] = row.unit ? `${row.setting}${row.unit}` : row.setting;
      return acc;
    }, {});
  }
}
