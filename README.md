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
- npm
- Docker & Docker Compose

### Local Development

```bash
# Clone with all submodules
git clone --recurse-submodules https://github.com/payloops/loop.git
cd loop

# Start infrastructure (PostgreSQL, Temporal, OpenObserve, OTel Collector)
docker-compose up -d

# Terminal 1: Start API server
cd backend && npm install && npm dev

# Terminal 2: Start workflow workers
cd processor-core && npm install && npm dev

# Terminal 3: Start dashboard
cd dashboard && npm install && npm dev
```

### Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Backend API | http://localhost:3000 | - |
| Dashboard | http://localhost:5173 | - |
| Temporal UI | http://localhost:8080 | - |
| OpenObserve | http://localhost:5080 | admin@loop.dev / admin123 |
| OTel Collector | gRPC: 4317, HTTP: 4318 | - |

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

## Observability

PayLoops uses OpenTelemetry for unified observability with all telemetry data flowing to OpenObserve.

### Architecture

```
                         OpenObserve (localhost:5080)
                                  │
           ┌──────────────────────┼──────────────────────┐
           │                      │                      │
       Logs API             OTLP HTTP              OTLP HTTP
     (5080/api)          (:4318/traces)        (:4318/metrics)
           │                      │                      │
           └──────────────────────┼──────────────────────┘
                                  │
   ┌──────────────────────────────┴───────────────────────────┐
   │              OpenTelemetry Collector (:4317/:4318)        │
   │   - Receives OTLP from apps                              │
   │   - Scrapes Temporal server Prometheus metrics (:8000)   │
   │   - Forwards all to OpenObserve                          │
   └─────────────────────────────┬────────────────────────────┘
              ▲                  │                  ▲
              │                  │                  │
   ┌──────────┴────┐    ┌───────┴───────┐   ┌─────┴────────┐
   │    Backend    │    │    Temporal   │   │  Processor   │
   │    (Hono)     │    │    Server     │   │    Core      │
   │  OTLP push    │    │ Prometheus    │   │  OTLP push   │
   └───────────────┘    └───────────────┘   └──────────────┘
```

### What's Collected

| Source | Data Type | Method |
|--------|-----------|--------|
| Backend | Traces, Metrics, Logs | Direct OTLP push |
| Processor-Core | Traces, Metrics, Logs | Direct OTLP push |
| Temporal Server | Metrics | OTel Collector scrapes Prometheus endpoint |

### Correlation IDs

Every request gets a correlation ID (`X-Correlation-ID` header) that flows through:
- HTTP requests → API handlers → Temporal workflows → Activities

This enables end-to-end tracing across services:

```bash
# Make a request with correlation ID
curl -H "X-Correlation-ID: test-123" http://localhost:3000/health

# Or let the system generate one (returned in response header)
curl -v http://localhost:3000/health
```

### Viewing Telemetry

1. Open OpenObserve: http://localhost:5080
2. Login: `admin@loop.dev` / `admin123`
3. Navigate to:
   - **Logs**: Search by `correlationId`, `trace_id`, or service name
   - **Traces**: View distributed traces across services
   - **Metrics**: Monitor `temporal_*` metrics, payment counters, latency histograms

### Key Metrics

| Metric | Description |
|--------|-------------|
| `payment_attempts_total` | Total payment attempts by processor and status |
| `payment_amount_total` | Total payment amount processed |
| `payment_latency_seconds` | Payment processing latency |
| `webhook_deliveries_total` | Webhook delivery attempts |
| `temporal_workflow_*` | Temporal workflow execution metrics |
| `temporal_activity_*` | Temporal activity execution metrics |

### Environment Variables

```bash
# OpenTelemetry configuration
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_SERVICE_NAME=loop-backend  # or loop-processor-core
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
