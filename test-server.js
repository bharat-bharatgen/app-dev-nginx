const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = 8084;

// HTTP Routes
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Test Server - medsum.bharatgen.dev</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          max-width: 800px;
          margin: 50px auto;
          padding: 20px;
          background-color: #f5f5f5;
        }
        .container {
          background: white;
          padding: 30px;
          border-radius: 8px;
          box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .status {
          color: #28a745;
          font-weight: bold;
        }
        #wsStatus {
          margin-top: 20px;
          padding: 10px;
          background: #e9ecef;
          border-radius: 4px;
        }
        button {
          background: #007bff;
          color: white;
          border: none;
          padding: 10px 20px;
          border-radius: 4px;
          cursor: pointer;
          margin-top: 10px;
        }
        button:hover {
          background: #0056b3;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>Test Server Running</h1>
        <p class="status">✓ Server is running on port ${PORT}</p>
        <p>Domain: <strong>medsum.bharatgen.dev</strong></p>
        <p>Timestamp: ${new Date().toISOString()}</p>

        <h2>WebSocket Test</h2>
        <button onclick="testWebSocket()">Test WebSocket Connection</button>
        <div id="wsStatus"></div>
      </div>

      <script>
        function testWebSocket() {
          const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
          const ws = new WebSocket(protocol + '//' + window.location.host + '/ws');
          const statusDiv = document.getElementById('wsStatus');

          ws.onopen = function() {
            statusDiv.innerHTML = '<strong style="color: green;">✓ WebSocket Connected!</strong>';
            ws.send('Hello from client at ' + new Date().toISOString());
          };

          ws.onmessage = function(event) {
            statusDiv.innerHTML += '<br>Server says: ' + event.data;
          };

          ws.onerror = function(error) {
            statusDiv.innerHTML = '<strong style="color: red;">✗ WebSocket Error</strong>';
          };

          ws.onclose = function() {
            statusDiv.innerHTML += '<br><em>Connection closed</em>';
          };
        }
      </script>
    </body>
    </html>
  `);
});

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    port: PORT,
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.get('/api/test', (req, res) => {
  res.json({
    message: 'API endpoint working',
    server: 'medsum.bharatgen.dev test server',
    timestamp: new Date().toISOString()
  });
});

// WebSocket handling
wss.on('connection', (ws) => {
  console.log('New WebSocket connection established');

  ws.send('Welcome to medsum.bharatgen.dev WebSocket server!');

  ws.on('message', (message) => {
    console.log('Received:', message.toString());
    ws.send(`Echo: ${message.toString()} (received at ${new Date().toISOString()})`);
  });

  ws.on('close', () => {
    console.log('WebSocket connection closed');
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Start server
server.listen(PORT, () => {
  console.log(`Test server running on http://localhost:${PORT}`);
  console.log(`WebSocket server ready`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, closing server gracefully...');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
