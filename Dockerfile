FROM node:20-alpine

# Build tools for better-sqlite3 native compilation on Linux
RUN apk add --no-cache python3 make g++ sqlite-dev

WORKDIR /app

# Install server dependencies (termasuk better-sqlite3 dengan prebuilt Linux binary)
COPY server/package*.json ./server/
RUN cd server && npm install --build-from-source

# Copy source code and web assets
COPY server ./server
COPY index.js package*.json ./
RUN npm install --ignore-scripts

# Create data directories
RUN mkdir -p /app/server/data/uploads /app/server/data/quarantine
VOLUME ["/app/server/data"]

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

CMD ["node", "server/src/index.js"]
