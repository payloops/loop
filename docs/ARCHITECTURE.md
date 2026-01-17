# Loop Payment Platform - Architecture

## Overview

Loop is a payment routing platform that enables merchants to process payments through multiple payment processors (Stripe, Razorpay) with intelligent routing, retry logic, and comprehensive webhook handling.

## Repository Structure

```
loop/
├── dashboard/          → SvelteKit merchant dashboard
├── backend/            → Hono API server
├── processor-core/     → Shared Temporal workflows & activities
├── processor-stripe/   → Stripe processor implementation
├── processor-razorpay/ → Razorpay processor implementation
├── observability/      → Shared observability package (@payloops/observability)
├── backend-worker/     → Backend Temporal worker for DB operations
└── infrastructure/     → Terraform + Kamal deployment configs
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Frontend** | SvelteKit, TailwindCSS, TypeScript |
| **API** | Hono, TypeScript, Zod |
| **Workers** | @astami/temporal-functions, Temporal |
| **Database** | PostgreSQL |
| **Cache** | Redis |
| **Analytics** | OpenObserve |
| **Auth** | Custom JWT + API Keys |
| **Deployment** | Kamal |
| **Infrastructure** | Terraform (Hetzner) |

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MERCHANT LAYER                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────┐         ┌──────────────┐         ┌──────────────┐        │
│   │   Merchant   │         │   Merchant   │         │   Merchant   │        │
│   │   Website    │         │   Mobile App │         │   Dashboard  │        │
│   └──────┬───────┘         └──────┬───────┘         └──────┬───────┘        │
│          │                        │                        │                 │
│          │  @payloops/sdk             │  @payloops/sdk             │                 │
│          ▼                        ▼                        ▼                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                               API LAYER (backend)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         Hono API Server                              │   │
│   ├─────────────────────────────────────────────────────────────────────┤   │
│   │                                                                      │   │
│   │  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐    │   │
│   │  │  Payment   │  │  Merchant  │  │  Webhook   │  │  Checkout  │    │   │
│   │  │  Routes    │  │  Routes    │  │  Routes    │  │  Routes    │    │   │
│   │  └────────────┘  └────────────┘  └────────────┘  └────────────┘    │   │
│   │                                                                      │   │
│   │  ┌────────────────────────────────────────────────────────────┐    │   │
│   │  │              Middleware (Auth, Rate Limit, Logging)         │    │   │
│   │  └────────────────────────────────────────────────────────────┘    │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│                                    │ Temporal Client                         │
│                                    ▼                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       WORKFLOW LAYER (processor-core)                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                      Temporal Server                                 │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                @astami/temporal-functions Workers                    │   │
│   ├─────────────────────────────────────────────────────────────────────┤   │
│   │                                                                      │   │
│   │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │   │
│   │  │ PaymentWorkflow │  │ RefundWorkflow  │  │ WebhookWorkflow │     │   │
│   │  │                 │  │                 │  │                 │     │   │
│   │  │ - Create Order  │  │ - Init Refund   │  │ - Receive Hook  │     │   │
│   │  │ - Route Payment │  │ - Process       │  │ - Validate      │     │   │
│   │  │ - Charge        │  │ - Notify        │  │ - Dispatch      │     │   │
│   │  │ - Handle 3DS    │  │                 │  │ - Retry Failed  │     │   │
│   │  │ - Confirm       │  │                 │  │                 │     │   │
│   │  └─────────────────┘  └─────────────────┘  └─────────────────┘     │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                         │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PROCESSOR LAYER (separate repos)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐     │
│   │ processor-stripe │    │processor-razorpay│    │  Future Gateway  │     │
│   │                  │    │                  │    │                  │     │
│   │ - createPayment  │    │ - createPayment  │    │ - createPayment  │     │
│   │ - capturePayment │    │ - capturePayment │    │ - capturePayment │     │
│   │ - refundPayment  │    │ - refundPayment  │    │ - refundPayment  │     │
│   └──────────────────┘    └──────────────────┘    └──────────────────┘     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DATA LAYER                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌──────────────┐         ┌──────────────┐         ┌──────────────┐        │
│   │  PostgreSQL  │         │    Redis     │         │ OpenObserve  │        │
│   │  (Primary)   │         │   (Cache)    │         │  (Analytics) │        │
│   └──────────────┘         └──────────────┘         └──────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Core Workflows

### 1. Payment Flow

```
┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐
│ Create │ ──► │ Route  │ ──► │ Charge │ ──► │  3DS   │ ──► │Confirm │
│ Order  │     │Payment │     │        │     │(if req)│     │        │
└────────┘     └────────┘     └────────┘     └────────┘     └────────┘
     │              │              │              │              │
     ▼              ▼              ▼              ▼              ▼
  pending      processing     authorized     challenged     completed
```

### 2. Webhook Flow

```
Processor ──► Webhook Endpoint ──► Validate ──► Queue ──► Process ──► Notify Merchant
                                                  │
                                                  ▼
                                          Retry on Failure
                                          (exponential backoff)
```

## Database Schema (Core Tables)

```sql
-- Merchants
merchants (
  id, name, email, api_key_hash, webhook_url,
  created_at, updated_at
)

-- Payment Orders
orders (
  id, merchant_id, external_id, amount, currency,
  status, processor, processor_order_id,
  metadata, created_at, updated_at
)

-- Transactions
transactions (
  id, order_id, type, amount, status,
  processor_response, created_at
)

-- Webhook Events
webhook_events (
  id, merchant_id, event_type, payload,
  status, attempts, last_attempt_at, created_at
)

-- Processor Configs (per merchant)
processor_configs (
  id, merchant_id, processor, credentials_encrypted,
  priority, enabled, created_at
)
```

## API Endpoints

### Public API (for merchants via SDK)

```
POST   /v1/orders              - Create payment order
GET    /v1/orders/:id          - Get order status
POST   /v1/orders/:id/pay      - Process payment
POST   /v1/orders/:id/refund   - Initiate refund
GET    /v1/orders/:id/refunds  - List refunds

POST   /v1/checkout/sessions   - Create checkout session
```

### Webhook Endpoints

```
POST   /webhooks/stripe        - Stripe webhook receiver
POST   /webhooks/razorpay      - Razorpay webhook receiver
```

### Dashboard API (authenticated)

```
GET    /api/dashboard/stats    - Dashboard statistics
GET    /api/merchants/me       - Current merchant info
PUT    /api/merchants/me       - Update merchant settings
GET    /api/orders             - List orders
POST   /api/api-keys           - Generate new API key
DELETE /api/api-keys/:id       - Revoke API key
GET    /api/processors         - List configured processors
POST   /api/processors/:name   - Configure processor
```

## Security

### API Authentication

1. **Merchant API**: API Key in header `X-API-Key: sk_live_xxx`
2. **Dashboard**: JWT tokens with refresh mechanism
3. **Webhooks**: Signature verification per processor

### Data Security

- All processor credentials encrypted at rest (AES-256-GCM)
- PCI-DSS compliance considerations:
  - Never store raw card data
  - Use processor tokenization
  - TLS 1.3 for all connections

## Routing Logic

```typescript
interface RoutingRule {
  conditions: {
    currency?: string[];
    amount?: { min?: number; max?: number };
    cardBrand?: string[];
    country?: string[];
  };
  processor: 'stripe' | 'razorpay';
  priority: number;
}

// Default routing
const defaultRouting: RoutingRule[] = [
  { conditions: { currency: ['INR'] }, processor: 'razorpay', priority: 1 },
  { conditions: { currency: ['USD', 'EUR'] }, processor: 'stripe', priority: 1 },
  { conditions: {}, processor: 'stripe', priority: 99 }, // fallback
];
```

## Deployment Architecture (Hetzner)

```
┌─────────────────────────────────────────────────────────────────┐
│                        Hetzner Cloud                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   web-1     │  │   web-2     │  │   worker-1  │             │
│  │ (API+Dash)  │  │ (API+Dash)  │  │  (Temporal) │             │
│  │   CX31      │  │   CX31      │  │    CX41     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │               │                │                      │
│         └───────────────┼────────────────┘                      │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Load Balancer                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  db-1       │  │  redis-1    │  │ temporal-1  │             │
│  │ PostgreSQL  │  │   Redis     │  │  Temporal   │             │
│  │   CX41      │  │   CX21      │  │    CX31     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    OpenObserve                           │   │
│  │                      CX31                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Local Development

### Prerequisites

- Node.js 22+
- npm
- Docker & Docker Compose

### Quick Start

```bash
# Clone with all submodules
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

# Run backend
cd backend
cp .env.example .env
npm install
npm run dev

# Run dashboard (new terminal)
cd dashboard
cp .env.example .env
npm install
npm run dev

# Run workers (new terminal)
cd processor-core
cp .env.example .env
npm install
npm run dev
```

### Environment Variables

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

1. Create a new repo: `processor-{name}`
2. Implement the `PaymentProcessor` interface from `@payloops/processor-core`
3. Export a `register()` function that calls `registerProcessor()`
4. Import in `processor-core/worker.ts` to auto-register

Example:

```typescript
// processor-newgateway/src/index.ts
import { registerProcessor, type PaymentProcessor } from '@payloops/processor-core';

class NewGatewayProcessor implements PaymentProcessor {
  name = 'newgateway';

  async createPayment(input, config) {
    // Implementation
  }

  async capturePayment(orderId, amount, config) {
    // Implementation
  }

  async refundPayment(transactionId, amount, config) {
    // Implementation
  }

  async getPaymentStatus(orderId, config) {
    // Implementation
  }
}

export function register() {
  registerProcessor(new NewGatewayProcessor());
}

register();
```

## Project Status

- ✅ Architecture planning
- ✅ Dashboard repo (SvelteKit)
- ✅ Backend repo (Hono API)
- ✅ Processor-core repo (Temporal workflows)
- ✅ Processor-stripe repo
- ✅ Processor-razorpay repo
- ✅ SDK repo (sdk-ts)
- ✅ Observability package (@payloops/observability)
- ✅ Infrastructure (Terraform + Kamal)
- ✅ Local development setup
- ✅ CI/CD pipelines (GitHub Actions)
- 🔲 Production deployment
