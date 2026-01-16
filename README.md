# PayLoops

**PayLoops** is a payment orchestration platform that enables businesses to route payments intelligently across multiple payment processors. Built for reliability, scalability, and developer experience.

## Why PayLoops?

Modern businesses need flexibility in payment processing. Different processors excel in different regions, currencies, and use cases. PayLoops abstracts this complexity:

- **Smart Routing**: Automatically route payments to the optimal processor based on currency, amount, card type, or custom rules
- **Failover & Retry**: If one processor fails, automatically retry with another
- **Unified API**: Single integration point regardless of how many processors you use
- **Real-time Webhooks**: Reliable webhook delivery with automatic retries and exponential backoff
- **Complete Visibility**: Track every payment across all processors in one dashboard

## Architecture Overview

PayLoops follows a microservices architecture with clear separation of concerns:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            YOUR APPLICATION                               │
│                                                                          │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│   │   Website   │    │  Mobile App │    │   Backend   │                 │
│   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                 │
│          │                  │                  │                         │
│          └──────────────────┼──────────────────┘                         │
│                             │                                            │
│                    @payloops/sdk-ts                                      │
└─────────────────────────────┼────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           PAYLOOPS PLATFORM                              │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                        API Gateway (backend)                        │ │
│  │                                                                     │ │
│  │  • REST API for payment operations                                 │ │
│  │  • JWT authentication for dashboard                                │ │
│  │  • API key authentication for merchants                            │ │
│  │  • Webhook ingestion from processors                               │ │
│  └─────────────────────────────┬──────────────────────────────────────┘ │
│                                │                                         │
│  ┌─────────────────────────────▼──────────────────────────────────────┐ │
│  │                    Workflow Engine (processor-core)                 │ │
│  │                                                                     │ │
│  │  • Temporal-based durable workflows                                │ │
│  │  • Payment state machine (create → route → charge → confirm)       │ │
│  │  • 3DS challenge handling                                          │ │
│  │  • Webhook delivery with retry logic                               │ │
│  └─────────────────────────────┬──────────────────────────────────────┘ │
│                                │                                         │
│  ┌─────────────────────────────▼──────────────────────────────────────┐ │
│  │                       Payment Processors                            │ │
│  │                                                                     │ │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐   │ │
│  │  │ processor-stripe │  │processor-razorpay│  │  Your Gateway  │   │ │
│  │  └──────────────────┘  └──────────────────┘  └────────────────┘   │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        PAYMENT PROCESSORS                                │
│                                                                          │
│            Stripe  •  Razorpay  •  PayPal  •  Adyen  •  ...             │
└──────────────────────────────────────────────────────────────────────────┘
```

## Repository Structure

This is a multi-repo project. Each component is maintained separately for independent deployment and versioning:

| Repository | Purpose | Tech Stack |
|------------|---------|------------|
| **[loop](https://github.com/payloops/loop)** | Infrastructure, deployment configs, and documentation | Terraform, Kamal, Docker |
| **[backend](https://github.com/payloops/backend)** | REST API handling all external requests | Hono, TypeScript, Drizzle |
| **[processor-core](https://github.com/payloops/processor-core)** | Durable workflow engine for payment processing | Temporal, TypeScript |
| **[processor-stripe](https://github.com/payloops/processor-stripe)** | Stripe payment processor adapter | TypeScript, Stripe SDK |
| **[processor-razorpay](https://github.com/payloops/processor-razorpay)** | Razorpay payment processor adapter | TypeScript, Razorpay SDK |
| **[sdk-ts](https://github.com/payloops/sdk-ts)** | TypeScript SDK for merchant integration | TypeScript |
| **[dashboard](https://github.com/payloops/dashboard)** | Merchant dashboard for managing payments | SvelteKit, TailwindCSS |

## Quick Start

### Prerequisites

- Node.js 22+
- pnpm
- Docker & Docker Compose

### Local Development

```bash
# Clone with all submodules
git clone --recurse-submodules https://github.com/payloops/loop.git
cd loop

# Start infrastructure (PostgreSQL, Redis, Temporal)
docker-compose up -d

# Terminal 1: Start API server
cd backend && pnpm install && pnpm dev

# Terminal 2: Start workflow workers
cd processor-core && pnpm install && pnpm dev

# Terminal 3: Start dashboard
cd dashboard && pnpm install && pnpm dev
```

### Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Backend API | http://localhost:3000 | - |
| Dashboard | http://localhost:5173 | - |
| Temporal UI | http://localhost:8080 | - |
| OpenObserve | http://localhost:5080 | admin@loop.dev / admin123 |

## How It Works

### Payment Flow

1. **Merchant creates an order** via SDK or API
2. **Backend validates** and persists the order
3. **Workflow engine routes** the payment to optimal processor
4. **Processor adapter** communicates with external gateway
5. **On success/failure**, webhook is delivered to merchant

### Routing Rules

Default routing (configurable per merchant):

```
INR transactions     →  Razorpay (lower fees for India)
USD/EUR transactions →  Stripe (better international coverage)
Fallback             →  Stripe
```

## SDK Example

```typescript
import PayLoops from '@payloops/sdk';

const payloops = new PayLoops('sk_live_...');

// Create a payment order
const order = await payloops.orders.create({
  amount: 4999,        // $49.99 in cents
  currency: 'USD',
  metadata: { orderId: 'ORD-123' }
});

// Process payment with a tokenized card
const payment = await payloops.orders.pay(order.id, {
  paymentMethod: { type: 'card', token: 'pm_...' }
});

if (payment.status === 'requires_action') {
  // Redirect to payment.redirectUrl for 3DS
}
```

## Contributing

Each repository has its own contribution guidelines. For infrastructure changes, open issues in this repository.

## License

Copyright © 2025 PayLoops. All rights reserved.
