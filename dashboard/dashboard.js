// Initialize Chart.js
const ctx = document.getElementById('metricsChart').getContext('2d');
const metricsChart = new Chart(ctx, {
    type: 'line',
    data: {
        labels: [],
        datasets: [
            {
                label: 'CPU Usage',
                data: [],
                borderColor: '#1a73e8',
                tension: 0.4,
                fill: true,
                backgroundColor: 'rgba(26, 115, 232, 0.1)'
            },
            {
                label: 'Memory Usage',
                data: [],
                borderColor: '#34a853',
                tension: 0.4,
                fill: true,
                backgroundColor: 'rgba(52, 168, 83, 0.1)'
            },
            {
                label: 'Cache Hit Ratio',
                data: [],
                borderColor: '#fbbc05',
                tension: 0.4,
                fill: true,
                backgroundColor: 'rgba(251, 188, 5, 0.1)'
            }
        ]
    },
    options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
            duration: 0
        },
        scales: {
            y: {
                beginAtZero: true,
                max: 100
            }
        },
        plugins: {
            legend: {
                position: 'top'
            }
        }
    }
});

// Store historical data
const maxDataPoints = 50;
const historicalData = {
    timestamps: [],
    cpuUsage: [],
    memoryUsage: [],
    cacheHitRatio: []
};

// Format numbers for display
function formatNumber(value, decimals = 1) {
    if (value === null || value === undefined) return '-';
    return value.toFixed(decimals);
}

// Update metrics display
function updateMetricsDisplay(metrics) {
    document.getElementById('connections').textContent = metrics.connections;
    document.getElementById('cacheHitRatio').textContent = formatNumber(metrics.cacheHitRatio * 100) + '%';
    document.getElementById('cpuUsage').textContent = formatNumber(metrics.cpuUsage) + '%';
    document.getElementById('memoryUsage').textContent = formatNumber(metrics.memoryUsage) + '%';
}

// Update chart with new data
function updateChart(metrics, timestamp) {
    // Add new data
    historicalData.timestamps.push(new Date(timestamp).toLocaleTimeString());
    historicalData.cpuUsage.push(metrics.cpuUsage);
    historicalData.memoryUsage.push(metrics.memoryUsage);
    historicalData.cacheHitRatio.push(metrics.cacheHitRatio * 100);

    // Remove old data if we exceed maxDataPoints
    if (historicalData.timestamps.length > maxDataPoints) {
        historicalData.timestamps.shift();
        historicalData.cpuUsage.shift();
        historicalData.memoryUsage.shift();
        historicalData.cacheHitRatio.shift();
    }

    // Update chart
    metricsChart.data.labels = historicalData.timestamps;
    metricsChart.data.datasets[0].data = historicalData.cpuUsage;
    metricsChart.data.datasets[1].data = historicalData.memoryUsage;
    metricsChart.data.datasets[2].data = historicalData.cacheHitRatio;
    metricsChart.update();
}

// Update recommendations
function updateRecommendations(recommendations) {
    const recommendationsDiv = document.getElementById('recommendations');
    if (!recommendations || recommendations.length === 0) {
        recommendationsDiv.innerHTML = '<div class="recommendation">No recommendations at this time.</div>';
        return;
    }

    recommendationsDiv.innerHTML = recommendations.map(rec => `
        <div class="recommendation">
            <div class="d-flex justify-content-between align-items-start mb-3">
                <div class="parameter-name">
                    <strong>${rec.parameter}</strong>
                </div>
                <div>
                    <div class="impact-${rec.impact.toLowerCase()}">${rec.impact} Impact</div>
                    ${rec.requiresRestart ? '<div class="restart-required">Requires Restart</div>' : ''}
                </div>
            </div>
            <div class="value-pair">
                <div class="d-flex justify-content-between align-items-center">
                    <div>
                        <span class="text-muted">Current</span>
                        <div class="current-value">${rec.currentValue}</div>
                    </div>
                    <div class="value-arrow">→</div>
                    <div class="text-end">
                        <span class="text-muted">Recommended</span>
                        <div class="recommended-value">${rec.recommendedValue}</div>
                    </div>
                </div>
            </div>
            <small class="text-muted d-block mt-2">${rec.reasoning}</small>
        </div>
    `).join('');
}

// Update configuration table
function updateConfig(config) {
    const configTable = document.getElementById('configTable');
    configTable.innerHTML = Object.entries(config).map(([key, value]) => `
        <tr>
            <td>${key}</td>
            <td>${value.setting}</td>
            <td>${value.unit || '-'}</td>
            <td>${value.context}</td>
        </tr>
    `).join('');
}

// Fetch and update all data
async function updateDashboard() {
    try {
        // Get current metrics
        const metricsResponse = await fetch('/api/metrics');
        const metricsData = await metricsResponse.json();
        const metrics = JSON.parse(metricsData.content[0].text);
        updateMetricsDisplay(metrics.metrics);
        updateChart(metrics.metrics, metrics.timestamp);

        // Get recommendations (analyze last 30 minutes of metrics)
        const analysisResponse = await fetch('/api/analyze?timeRange=30');
        const analysisData = await analysisResponse.json();
        const analysis = JSON.parse(analysisData.content[0].text);
        updateRecommendations(analysis.recommendations);

        // Get configuration
        const configResponse = await fetch('/api/config');
        const configData = await configResponse.json();
        const config = JSON.parse(configData.content[0].text);
        updateConfig(config);

    } catch (error) {
        console.error('Error updating dashboard:', error);
    }
}

// Update dashboard every 5 seconds
setInterval(updateDashboard, 5000);

// Initial update
updateDashboard();
