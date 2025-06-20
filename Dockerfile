# Base image with Node.js
FROM node:22.12.0-alpine AS base

# Set working directory
WORKDIR /app

# Ensure libc6-compat is available for some Node.js modules
# This is good practice for Alpine-based Node.js images with certain native modules.
RUN apk add --no-cache libc6-compat

FROM base AS deps

# Copy only the necessary package manager files for dependency installation
COPY package.json pnpm-lock.yaml* ./

# Disable Corepack's strict signature verification for package manager binaries.
# This helps with the "Cannot find matching keyid" error.
ENV COREPACK_ENABLE_STRICT=0

RUN \
  # Enable pnpm explicitly with a specific version as recommended by package.json.
  # Using 'pnpm@9.4.0' as an example. Adjust if your project demands a different v9.x or v10.x version.
  corepack enable pnpm@9.4.0 && \
  pnpm install --frozen-lockfile

# Build application
FROM base AS builder

# Copy node_modules from the 'deps' stage
COPY --from=deps /app/node_modules ./node_modules
# Copy all other application source code
COPY . .

# Disable Next.js telemetry during build (optional but recommended for production builds)
ENV NEXT_TELEMETRY_DISABLED 1

# Re-enable pnpm explicitly in the builder stage to ensure consistency
ENV COREPACK_ENABLE_STRICT=0
RUN \
  corepack enable pnpm@9.4.0 && \
  pnpm build

# Create minimal runtime image
FROM node:22.12.0-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED 1
ENV PORT=3000

# Create a non-root user for security
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy public assets from the builder stage
COPY --from=builder /app/public ./public

# Set up Next.js standalone build output
# Ensure correct ownership for the non-root user
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Create and set permissions for the Next.js cache directory
RUN mkdir .next && chown nextjs:nodejs .next

# Switch to the non-root user
USER nextjs

# Expose the application port
EXPOSE 3000

# Command to start the Next.js application in standalone mode
CMD ["node", "server.js"]
