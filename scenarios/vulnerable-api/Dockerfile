FROM node:18-slim

LABEL org.opencontainers.image.source="https://github.com/CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios"
LABEL com.c2c.scenario="vulnerable-api"
LABEL com.c2c.vulnerability.primary="CVE-2020-15366"
LABEL com.c2c.vulnerability.secondary="CVE-2020-8203"

WORKDIR /app
COPY app/package*.json ./
RUN npm install --omit=dev
COPY app/server.js ./

EXPOSE 3001
CMD ["node", "server.js"]