---
name: tech-stack-preference
description: >
  Use to enforce or reference the agreed tech stack (Laravel 13 + React 19 +
  Inertia.js 3) during implementation, debugging, or code review. Activates on
  any code generation, dependency choice, or architecture decision to ensure
  stack consistency.
---

# Tech Stack Reference

## Runtime

- **Dev:** PHP 8.4+, Node.js v20+
- **Prod:** PHP 8.4+, Node.js v22 LTS
- **TypeScript:** Strict (no explicit any)
- **Package manager:** npm

## Frontend

| Area | Choice |
|---|---|
| Framework | React 19 |
| Adapter | Inertia.js 3 |
| Bundler | Vite 8 (`@vitejs/plugin-react`, `@inertiajs/vite`, `@tailwindcss/vite`) |
| Language | TypeScript 5.7+ |
| Styling | Tailwind CSS v4 |
| Primitives | ReUI (shadcn/ui + Radix UI + Motion) |
| Icons | Lucide React |
| Animation | Motion (Framer Motion) / tw-animate-css |
| Toast | Sonner |
| Table | ReUI Data Grid / Custom (`resources/js/components/tables`) |
| OTP | input-otp |
| Modal | Custom (`resources/js/components/modals`) |
| Kanban | ReUI Kanban Board |
| Tree | ReUI Tree View |
| Timeline | ReUI Timeline |
| Date picker | react-day-picker |
| Forms | Inertia React Forms (`useForm`) |
| Validation | Laravel server-side Form Requests |
| Server state | Inertia.js Page Props |
| Client state | React State / Context / Custom Hooks |
| URL state | Inertia.js routing + history state |
| Memoization | `useMemo` |
| Routing | Inertia.js + Laravel Routing |
| Route helper | Wayfinder (type-safe generated client routes) |
| HTTP client | Inertia Router / Axios (fallback) |
| Component dirs | `ui/`, `blocks/`, `common/`, `forms/`, `tables/`, `modals/` |

## Backend

| Area | Choice |
|---|---|
| Architecture | Modular Monolith (`app/Features`, DDD) |
| Framework | Laravel 13 |
| Runtime | PHP 8.4+ |
| ORM | Eloquent |
| Database | PostgreSQL |
| Migrations | `database/migrations` |
| Auth | Laravel Fortify (Session + Passkeys) |
| Authorization | Spatie Laravel Permission |
| Hashing | Argon2id |
| Cookies | SameSite HTTP-Only Secure |
| Rate limit | Laravel Rate Limiter (`throttle`) |
| Caching | Cache-Aside (PostgreSQL local, Redis prod) |
| Queues | Laravel Queues |
| Pub/sub | Laravel Events & Listeners, Reverb (WebSocket) |
| WebSocket | Laravel Reverb / Pusher |
| Streaming | Server-Sent Responses / Laravel SSE |
| Polling | Inertia reload / poll |
| Storage | Laravel Storage Facade |
| Object storage | Local (dev), S3 / R2 (prod) |
| Image processing | Intervention Image / GD / Imagick |
| Payments | Laravel Cashier (Stripe) / Custom |

## API Contract

- **Default:** Inertia.js (Monolith UI)
- **REST:** Optional (`routes/api/v1.php`, prefix `/api/v1`)
  - Auth: Laravel Sanctum (first-party) / Passport (third-party)
  - Serialization: Eloquent Resources / Spatie Laravel Data DTOs

## Data Layer

- **Migrations:** Standard Laravel migrations
- **Seeding:** `DatabaseSeeder`, `RolePermissionSeeder`, `UserSeeder`
- **Transactions:** Eloquent (`DB::transaction`)
- **Constraints:** `DB::prohibitDestructiveCommands()` in production

## AI

- **SDK:** Custom PHP SDKs (OpenAI PHP, Anthropic PHP)
- **Providers:** OpenAI, Anthropic, Gemini
- **Streaming:** StreamedResponse / SSE

## Search

- **Primary:** Laravel Scout (Meilisearch / Algolia / DB full-text)
- **Fallback:** PostgreSQL Full-Text Search / Eloquent fuzzy queries

## Feature Flags

- **Provider:** Laravel Pennant / Spatie Feature Flags
- **Local override:** env + database flags

## SEO

- **Strategy:** SSR via Vite SSR compiler + Inertia Head manager
- **Sitemap:** spatie/laravel-sitemap
- **Structured data:** JSON-LD from backend views

## Performance

- Route caching (`php artisan route:cache`)
- Config caching (`php artisan config:cache`)
- View caching (`php artisan view:cache`)
- Composer optimized autoloading (`--optimize-autoloader`)
- Vite chunking and asset versioning

## Infrastructure

| Area | Choice |
|---|---|
| DB | PostgreSQL |
| Cache/Queue | PostgreSQL (local), Redis / SQS (prod) |
| Storage | Local / S3 / R2 |
| Email | SMTP / Log (local) / Resend / Mailgun / SES (prod) |
| Errors | Sentry / Laravel Log stack |
| Logging | Laravel Stack (Pail for local tailing) |
| Testing | Pest / PHPUnit, GitHub Actions |
| Deployment | Deployment-neutral (Cloud, Forge, VPS, Docker) |

## Tooling

- **PHP lint:** Laravel Pint (`pint.json`)
- **PHP static analysis:** Larastan / PHPStan (`phpstan.neon`)
- **JS lint/format:** Biome (`biome.json`)
- **Type check:** TypeScript Compiler (`tsc --noEmit`)

## Dev Experience

- **Environment:** Dotenv (`.env`)
- **Commands:**
  - `composer dev` — starts server, queue listener, Vite dev
  - `composer setup:local` — first-time DB and key setup
  - `composer reset:local` — migrate fresh + seed
  - `composer lint` — run Pint
  - `composer analyse` — run PHPStan
  - `php artisan test` — run Pest tests
- **CLI:** Artisan
- **Helpers:** Ziggy / Wayfinder

## Architecture

- Pattern: Modular Monolith / DDD
- Frontend: Component-driven (`ui/blocks/layouts`)
- Backend: Feature domains (`app/Features`) + Actions + Services + DTOs (Spatie Laravel Data)

## UI Design Rules

- Override default themes, spacing, and tokens in CSS (Tailwind v4 config)
- Build domain/feature components from base primitives (ReUI blocks)
- Keep components clean, small, reusable
- Design dashboard consistency across all roles (Admin, Staff, Client)
- Component directories: `ui/`, `blocks/`, `common/`, `forms/`, `tables/`, `modals/`
