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
| `processor-core/` | Temporal workflows & workers | - |
| `processor-stripe/` | Stripe processor implementation | - |
| `processor-razorpay/` | Razorpay processor implementation | - |
| `sdk/` | TypeScript SDK for merchant integration | - |
| `infrastructure/` | Terraform + Kamal deployment configs | - |

## Common Commands

### Dashboard (SvelteKit)
```bash
cd dashboard
pnpm install
pnpm dev          # Start dev server
pnpm build        # Production build
pnpm check        # Type check with svelte-check
pnpm lint         # ESLint
```

### Backend (Hono API)
```bash
cd backend
pnpm install
pnpm dev          # Start dev server with hot reload
pnpm build        # Build with tsup
pnpm start        # Run production build
pnpm typecheck    # TypeScript check
pnpm lint         # ESLint

# Database commands (Drizzle)
pnpm db:generate  # Generate migrations
pnpm db:migrate   # Run migrations
pnpm db:push      # Push schema to DB
pnpm db:studio    # Open Drizzle Studio
```

### Processor Core (Temporal Workers)
```bash
cd processor-core
pnpm install
pnpm dev          # Start worker with hot reload
pnpm build        # Build library
pnpm start        # Run production worker
pnpm typecheck    # TypeScript check
```

### SDK
```bash
cd sdk
pnpm install
pnpm build        # Build ESM + CJS
pnpm dev          # Watch mode
pnpm test         # Run vitest tests
pnpm typecheck    # TypeScript check
```

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

3. **Processor Layer** (`processor-stripe/`, `processor-razorpay/`)
   - Each implements `PaymentProcessor` interface
   - Auto-registers via `registerProcessor()` pattern

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

## Tech Stack

- **Frontend**: SvelteKit 5, TailwindCSS 4, TypeScript
- **API**: Hono, Zod, Drizzle ORM
- **Workers**: @astami/temporal-functions, Temporal
- **Database**: PostgreSQL 16, Redis 7
- **Analytics**: OpenObserve
- **Deployment**: Kamal, Terraform (Hetzner)
