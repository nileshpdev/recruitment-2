# Base image with Node.js
FROM node:22.12.0-alpine AS base

# Set working directory
WORKDIR /app

# Ensure libc6-compat is available for some Node.js modules
RUN apk add --no-cache libc6-compat

FROM base AS deps

COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./

ENV COREPACK_ENABLE_STRICT=0

RUN \
  if [ -f yarn.lock ]; then corepack enable yarn && yarn install --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install --frozen-lockfile; \
  else echo "No lockfile found." && exit 1; \
  fi



# Build application
FROM base AS builder

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Disable Next.js telemetry during build (optional but recommended for production builds)
ENV NEXT_TELEMETRY_DISABLED 1

# Ensure dependencies are reinstalled correctly (helps in CI environments)
ENV COREPACK_ENABLE_STRICT=0

RUN \
  if [ -f yarn.lock ]; then corepack enable yarn && yarn install --frozen-lockfile; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install --frozen-lockfile; \
  else echo "No lockfile found." && exit 1; \
  fi

RUN yarn build || npm run build || pnpm build

# Create minimal runtime image
FROM node:22.12.0-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED 1
ENV PORT=3000

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy public assets
COPY --from=builder /app/public ./public

# Set up Next.js standalone build output
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Set permissions for Next.js cache
RUN mkdir .next && chown nextjs:nodejs .next

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]
