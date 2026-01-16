# PayLoops

Payment routing platform enabling merchants to process payments through multiple processors with intelligent routing, retry logic, and webhook handling.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         MERCHANT LAYER                          │
│   Website / Mobile App / Dashboard  ──►  @payloops/sdk-ts       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          API LAYER                              │
│                    Hono API Server (backend)                    │
│   Payment Routes │ Webhook Handlers │ Dashboard API │ Auth      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       WORKFLOW LAYER                            │
│              Temporal + @astami/temporal-functions              │
│   PaymentWorkflow │ RefundWorkflow │ WebhookDeliveryWorkflow    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PROCESSOR LAYER                            │
│          processor-stripe  │  processor-razorpay  │  ...        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        DATA LAYER                               │
│           PostgreSQL  │  Redis  │  OpenObserve                  │
└─────────────────────────────────────────────────────────────────┘
```

## Repositories

| Repository | Description |
|------------|-------------|
| [loop](https://github.com/payloops/loop) | Parent repo with infrastructure and submodules |
| [dashboard](https://github.com/payloops/dashboard) | SvelteKit merchant dashboard |
| [backend](https://github.com/payloops/backend) | Hono API server |
| [processor-core](https://github.com/payloops/processor-core) | Temporal workflows and core logic |
| [processor-stripe](https://github.com/payloops/processor-stripe) | Stripe payment processor |
| [processor-razorpay](https://github.com/payloops/processor-razorpay) | Razorpay payment processor |
| [sdk-ts](https://github.com/payloops/sdk-ts) | TypeScript SDK for merchants |

## Quick Start

```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/payloops/loop.git
cd loop

# Start infrastructure services
docker-compose up -d

# Services available:
# - PostgreSQL: localhost:5432
# - Redis: localhost:6379
# - Temporal: localhost:7233
# - Temporal UI: localhost:8080
# - OpenObserve: localhost:5080

# Run backend (new terminal)
cd backend
cp .env.example .env
pnpm install
pnpm dev

# Run dashboard (new terminal)
cd dashboard
cp .env.example .env
pnpm install
pnpm dev

# Run workers (new terminal)
cd processor-core
cp .env.example .env
pnpm install
pnpm dev
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Frontend** | SvelteKit 5, TailwindCSS 4, TypeScript |
| **API** | Hono, Zod, Drizzle ORM |
| **Workers** | @astami/temporal-functions, Temporal |
| **Database** | PostgreSQL 16 |
| **Cache** | Redis 7 |
| **Analytics** | OpenObserve |
| **Auth** | JWT + API Keys |
| **Deployment** | Kamal |
| **Infrastructure** | Terraform (Hetzner) |

## Payment Routing

Default routing rules:
- INR currency → Razorpay
- USD/EUR currency → Stripe
- Fallback → Stripe

Custom routing rules can be configured per merchant.

## SDK Usage

```typescript
import PayLoops from '@payloops/sdk';

const client = new PayLoops('sk_test_xxx');

// Create an order
const order = await client.orders.create({
  amount: 1999, // cents
  currency: 'USD',
  customerEmail: 'customer@example.com'
});

// Process payment
const result = await client.orders.pay(order.id, {
  paymentMethod: {
    type: 'card',
    token: 'pm_xxx'
  }
});
```

## License

Proprietary - PayLoops
