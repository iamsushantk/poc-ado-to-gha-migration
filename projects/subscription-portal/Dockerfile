# syntax=docker/dockerfile:1

FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force

FROM node:20-alpine AS builder
WORKDIR /app
ARG APP_ENVIRONMENT=unknown
ARG APP_BUILD_ID=unknown
ENV APP_ENVIRONMENT=$APP_ENVIRONMENT
ENV APP_BUILD_ID=$APP_BUILD_ID
COPY package.json package-lock.json* ./
RUN npm install --no-audit --no-fund
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ARG APP_ENVIRONMENT=unknown
ARG APP_BUILD_ID=unknown
ENV NODE_ENV=production
ENV PORT=8080
ENV APP_ENVIRONMENT=$APP_ENVIRONMENT
ENV APP_BUILD_ID=$APP_BUILD_ID

# Next.js standalone output bundles only the files needed to run the app.
# This application has no public directory, so there is no static asset copy.
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 8080
CMD ["node", "server.js"]
