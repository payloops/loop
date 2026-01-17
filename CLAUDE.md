# Loop Payment Platform

Payment routing platform enabling merchants to process payments through multiple processors (Stripe, Razorpay) with intelligent routing, retry logic, and webhook handling.

## Quick Start

```bash
# Start infrastructure services
docker-compose up -d

# Services available:
# - PostgreSQL: localhost:5432
# - Redis: localhost:6379
# - Temporal: localhost:7233
# - Temporal UI: localhost:8080
# - OpenObserve: localhost:5080
```

## Repository Structure

| Directory | Description | Port |
|-----------|-------------|------|
| `dashboard/` | SvelteKit merchant dashboard | 5173 |
| `backend/` | Hono API server | 3000 |
| `backend-worker/` | Temporal worker for DB activities | - |
| `processor-core/` | Temporal workflows & payment types | - |
| `processor-stripe/` | Stripe processor implementation | - |
| `processor-razorpay/` | Razorpay processor implementation | - |
| `observability/` | Shared OpenTelemetry & logging utilities | - |
| `sdk/` | TypeScript SDK for merchant integration | - |
| `infrastructure/` | Terraform + Kamal deployment configs | - |

## npm Packages

| Package | Description |
|---------|-------------|
| `@payloops/observability` | OpenTelemetry, Pino logger, correlation context |
| `@payloops/processor-core` | PaymentProcessor interface, workflow types |
| `@payloops/backend-worker` | DB activities for Temporal workflows |

## Common Commands

### Dashboard (SvelteKit)
```bash
cd dashboard
npm install
npm run dev          # Start dev server
npm run build        # Production build
npm run check        # Type check with svelte-check
npm run lint         # ESLint
```

### Backend (Hono API)
```bash
cd backend
npm install
npm run dev          # Start dev server with hot reload
npm run build        # Build with tsup
npm run start        # Run production build
npm run typecheck    # TypeScript check
npm run lint         # ESLint

# Database commands (Drizzle)
npm run db:generate  # Generate migrations
npm run db:migrate   # Run migrations
npm run db:push      # Push schema to DB
npm run db:studio    # Open Drizzle Studio
```

### Processor Core
```bash
cd processor-core
npm install
npm run build        # Build library
npm run typecheck    # TypeScript check
npm run lint         # ESLint
npm run release      # Bump patch version, push, create tag
```

### Observability
```bash
cd observability
npm install
npm run build        # Build library
npm run typecheck    # TypeScript check
npm run lint         # ESLint
npm run release      # Bump patch version, push, create tag
```

### Backend Worker
```bash
cd backend-worker
npm install
npm run dev          # Start worker with hot reload
npm run build        # Build library
npm run start        # Run production worker
npm run typecheck    # TypeScript check
```

### SDK
```bash
cd sdk
npm install
npm run build        # Build ESM + CJS
npm run dev          # Watch mode
npm run test         # Run vitest tests
npm run typecheck    # TypeScript check
```

## CI/CD Workflow

### Release Process (for npm packages)
1. Run `npm run release` (or `release:minor`, `release:major`)
   - Builds and typechecks
   - Bumps version in package.json
   - Commits and pushes with git tag
2. Create GitHub release from the tag
   - This triggers the publish workflow
   - Package is published to npm

### GitHub Actions
- **CI** (`ci.yml`): Runs on push/PR to main - typecheck, lint, build
- **Publish** (`publish.yml`): Runs on GitHub release - publishes to npm

## Architecture Overview

### Payment Flow
```
Create Order -> Route Payment -> Charge -> 3DS (if required) -> Confirm
    |              |              |              |              |
 pending      processing     authorized     challenged     completed
```

### Key Components

1. **API Layer** (`backend/`)
   - Hono server with Zod validation
   - JWT + API Key authentication
   - Routes: `/v1/orders`, `/webhooks/stripe`, `/webhooks/razorpay`

2. **Workflow Layer** (`processor-core/`)
   - Uses `@astami/temporal-functions` framework
   - `PaymentWorkflow` - handles full payment lifecycle with 3DS signals
   - `WebhookDeliveryWorkflow` - delivers webhooks with exponential backoff retry

3. **Backend Worker** (`backend-worker/`)
   - Temporal worker for DB activities
   - Cross-queue pattern: processors call backend-operations queue
   - Activities: `getProcessorConfig`, `updateOrderStatus`, `deliverWebhook`

4. **Processor Layer** (`processor-stripe/`, `processor-razorpay/`)
   - Each implements `PaymentProcessor` interface
   - Auto-registers via `registerProcessor()` pattern

5. **Observability** (`observability/`)
   - OpenTelemetry SDK initialization
   - Pino logger with trace context
   - Correlation context via AsyncLocalStorage
   - Metrics for payments, webhooks, HTTP, workflows

### Database Schema (Key Tables)
- `merchants` - merchant accounts
- `orders` - payment orders with status tracking
- `transactions` - individual payment transactions
- `webhook_events` - outbound webhook delivery tracking
- `processor_configs` - encrypted processor credentials per merchant

### Routing Logic
- INR currency -> Razorpay
- USD/EUR currency -> Stripe
- Fallback -> Stripe

## Key Files

- `backend/src/db/schema.ts` - Drizzle database schema
- `backend/src/middleware/auth.ts` - JWT + API key authentication
- `backend/src/lib/crypto.ts` - AES-256-GCM encryption for credentials
- `processor-core/src/types/index.ts` - PaymentProcessor interface
- `processor-core/src/lib/registry.ts` - Processor registration
- `processor-core/src/workflows/payment.ts` - Payment workflow
- `observability/src/lib/otel.ts` - OpenTelemetry initialization
- `observability/src/lib/logger.ts` - Pino logger with trace context
- `observability/src/lib/context.ts` - Correlation context
- `backend-worker/src/functions/db.ts` - DB activities
- `sdk/src/client.ts` - SDK HTTP client

## Environment Variables

```bash
# Database
DATABASE_URL=postgresql://loop:loop@localhost:5432/loop
REDIS_URL=redis://localhost:6379

# Temporal
TEMPORAL_ADDRESS=localhost:7233
TEMPORAL_NAMESPACE=loop

# Auth
JWT_SECRET=your-super-secret-jwt-key-at-least-32-chars
ENCRYPTION_KEY=your-encryption-key-at-least-32-chars

# CORS
CORS_ORIGINS=http://localhost:5173

# OpenTelemetry (optional)
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_SERVICE_NAME=loop-backend
```

## Adding a New Payment Processor

1. Create new repo: `processor-{name}/`
2. Implement `PaymentProcessor` interface from `@payloops/processor-core`
3. Export and call `register()` function
4. Import in `processor-core` to auto-register

```typescript
import { registerProcessor, type PaymentProcessor } from '@payloops/processor-core';

class NewProcessor implements PaymentProcessor {
  name = 'newprocessor';
  async createPayment(input, config) { /* ... */ }
  async capturePayment(orderId, amount, config) { /* ... */ }
  async refundPayment(transactionId, amount, config) { /* ... */ }
  async getPaymentStatus(orderId, config) { /* ... */ }
}

export function register() {
  registerProcessor(new NewProcessor());
}
register();
```

## Using Observability

```typescript
import { initTelemetry, logger, withCorrelationContext } from '@payloops/observability';

// Initialize at app startup
initTelemetry({ serviceName: 'my-service' });

// Logger automatically includes trace context
logger.info({ orderId: '123' }, 'Processing order');

// Wrap requests with correlation context
app.use(async (c, next) => {
  await withCorrelationContext({ correlationId: c.req.header('x-correlation-id') }, next);
});
```

## Tech Stack

- **Frontend**: SvelteKit 5, TailwindCSS 4, TypeScript
- **API**: Hono, Zod, Drizzle ORM
- **Workers**: @astami/temporal-functions, Temporal
- **Database**: PostgreSQL 16, Redis 7
- **Observability**: OpenTelemetry, Pino, OpenObserve
- **Deployment**: Kamal, Terraform (Hetzner)
