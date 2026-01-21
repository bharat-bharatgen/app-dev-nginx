# Dockerfile for medsum test server
FROM node:24-alpine

WORKDIR /app

# Copy package files
COPY package.json ./

# Install dependencies
RUN npm install --production

# Copy server code
COPY test-server.js ./

# Expose port 8084
EXPOSE 8084

# Start the server
CMD ["node", "test-server.js"]
