FROM node:16-alpine

LABEL org.opencontainers.image.source="https://github.com/CESECEphemeralTestTenants-AspmAtlasProd/code2cloud-scenarios"
LABEL com.c2c.scenario="vulnerable-container"
LABEL com.c2c.vulnerability.primary="CVE-2020-15366"

WORKDIR /app
COPY app/package*.json ./
RUN npm install --omit=dev
COPY app/server.js ./

EXPOSE 3000
CMD ["node", "server.js"]