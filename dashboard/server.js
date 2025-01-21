import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const port = 3002;

// Serve static files
app.use(express.static(__dirname));

// API endpoints
app.get('/api/metrics', async (req, res) => {
    try {
        const response = await fetch('http://localhost:3001/mcp', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                jsonrpc: '2.0',
                id: 1,
                method: 'callTool',
                params: {
                    name: 'get_performance_metrics',
                    arguments: {}
                }
            })
        });
        const data = await response.json();
        if (data.error) {
            throw new Error(data.error);
        }
        res.json(data);
    } catch (error) {
        console.error('Error fetching metrics:', error);
        res.status(500).json({ error: 'Failed to fetch metrics' });
    }
});

app.get('/api/analyze', async (req, res) => {
    try {
        const response = await fetch('http://localhost:3001/mcp', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                jsonrpc: '2.0',
                id: 1,
                method: 'callTool',
                params: {
                    name: 'analyze_performance',
                    arguments: {
                        timeRange: req.query.timeRange || '1h'
                    }
                }
            })
        });
        const data = await response.json();
        if (data.error) {
            throw new Error(data.error);
        }
        res.json(data);
    } catch (error) {
        console.error('Error analyzing performance:', error);
        res.status(500).json({ error: 'Failed to analyze performance' });
    }
});

app.get('/api/config', async (req, res) => {
    try {
        const response = await fetch('http://localhost:3001/mcp', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                jsonrpc: '2.0',
                id: 1,
                method: 'callTool',
                params: {
                    name: 'get_config',
                    arguments: {}
                }
            })
        });
        const data = await response.json();
        if (data.error) {
            throw new Error(data.error);
        }
        res.json(data);
    } catch (error) {
        console.error('Error fetching config:', error);
        res.status(500).json({ error: 'Failed to fetch configuration' });
    }
});

// Start server
app.listen(port, () => {
    console.log(`Dashboard server running at http://localhost:${port}`);
});
