# Stage 1: Builder
FROM node:20 AS builder

ARG GITHUB_SHA=local-dev
ENV GITHUB_SHA=${GITHUB_SHA}

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm ci

COPY server.js ./
COPY public ./public
COPY scripts ./scripts

RUN npm run build

# Stage 2: Production runtime
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

COPY --from=builder /app/server.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/dist ./dist

USER node

EXPOSE 4173

CMD ["node", "server.js"]
