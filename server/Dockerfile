FROM node:20-alpine

WORKDIR /app

# Salin dependencies
COPY package*.json ./
RUN npm ci --only=production

# Salin source code dan public web assets
COPY src ./src
COPY public ./public

# Setup direktori data SQLite & uploads
RUN mkdir -p /app/data /app/uploads
VOLUME ["/app/data", "/app/uploads"]

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

CMD ["node", "src/index.js"]
