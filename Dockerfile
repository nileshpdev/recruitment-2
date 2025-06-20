# Base image with Node.js
FROM node:22.12.0-alpine AS base

# Set working directory
WORKDIR /app

# Ensure libc6-compat is available for some Node.js modules
RUN apk add --no-cache libc6-compat

FROM base AS deps

# Copy only the necessary package manager files for dependency installation
COPY package.json pnpm-lock.yaml* ./

# Disable Corepack's strict signature verification for package manager binaries.
ENV COREPACK_ENABLE_STRICT=0

# STEP 1: Prepare and activate pnpm. This ensures the pnpm binary is available globally.
# We're splitting this from the install command.
RUN corepack prepare pnpm@9.4.0 --activate

# STEP 2: Now that pnpm is prepared and activated, run the install command.
# This runs in a new shell session where pnpm should be in the PATH.
RUN pnpm install --frozen-lockfile

# Build application
FROM base AS builder

# Copy node_modules from the 'deps' stage
COPY --from=deps /app/node_modules ./node_modules
# Copy all other application source code
COPY . .

# Disable Next.js telemetry during build (optional but recommended for production builds)
ENV NEXT_TELEMETRY_DISABLED 1

# Re-ensure COREPACK_ENABLE_STRICT is set for the builder stage as well.
ENV COREPACK_ENABLE_STRICT=0

# STEP 1 (Builder stage): Prepare and activate pnpm again.
RUN corepack prepare pnpm@9.4.0 --activate

# STEP 2 (Builder stage): Now, run the build command.
RUN pnpm build

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
