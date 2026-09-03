FROM node:22-alpine

WORKDIR /app

# Salin dependencies server
COPY server/package*.json ./server/
RUN cd server && npm install --omit=dev

# Salin source code dan public web assets
COPY server ./server
COPY index.js package.json ./

# Setup direktori data SQLite & uploads
RUN mkdir -p /app/server/data /app/server/data/uploads
VOLUME ["/app/server/data"]

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0

EXPOSE 3000

CMD ["node", "server/src/index.js"]
