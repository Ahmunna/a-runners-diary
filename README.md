# A Runner's Diary 🏃

A personal AI running coach. Connect your Strava, set a race goal, and get a
training program generated and continuously adapted by Claude based on your
real activity data, how you feel, and what you eat.

> Status: early build, used by the author and friends. Not yet public.

## Core idea

1. You create an account and tell us about yourself (age, sex, height, any
   injuries or context you want the AI to know about).
2. You set a race goal: distance (5K / 10K / half / marathon / Hyrox), date, target
   time, and a difficulty level (beginner / intermediate / advanced).
3. You connect Strava. Every activity you log syncs in automatically, and we
   use your recent history to assess your current level.
4. You bring your own Claude API key. Claude reads your profile, your race
   goal, your training history, and your nutrition logs, and:
   - generates your initial training program
   - re-adapts it when you skip a day or under/over-perform
   - gives you a running opinion on your progress
   - chats with you directly about how you feel
5. Each day you see today's workout, macro suggestions, and Claude's latest
   take on your training — and you can log meals/calories for more context.
6. Your coach automatically checks in once a day at your local 9am, and
   whenever a new Strava activity comes in. You can opt into more frequent
   reviews (after every chat message, after every nutrition log) in
   Settings, or just tap "Ask coach to review now" any time.
7. Install it to your phone's home screen for push notifications whenever
   your coach updates its take on your progress.

## Stack

| Layer | Choice |
|---|---|
| Framework | Ruby on Rails 7.2 |
| Database | PostgreSQL 16 |
| Background jobs | Solid Queue (DB-backed, no Redis) |
| Auth | Devise |
| CSS | Tailwind CSS |
| JS | Hotwire (Turbo + Stimulus) |
| External APIs | Strava API (OAuth + Webhooks), Anthropic Claude API (per-athlete key) |
| Containers | Docker + Docker Compose |
| Deploy | Fly.io |

See [TECHNICAL_SPEC.md](TECHNICAL_SPEC.md) for architecture,
[PRODUCT_SPEC.md](PRODUCT_SPEC.md) for the product behavior, and
[CLAUDE_SETUP_GUIDE.md](CLAUDE_SETUP_GUIDE.md) for the customer-facing guide
on getting a Claude API key and what it costs.

## Local development

```bash
cp .env.example .env   # fill in Strava credentials once you have them
docker compose up
```

The app boots on http://localhost:3000. Postgres data persists in the
`postgres_data` volume.

Run migrations / seed manually if needed:

```bash
docker compose exec web bin/rails db:prepare
```

## Environment variables

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Postgres connection string |
| `SECRET_KEY_BASE` | Rails session/cookie secret |
| `STRAVA_CLIENT_ID` | Strava app client id (app-level, one app for all athletes) |
| `STRAVA_CLIENT_SECRET` | Strava app client secret |
| `STRAVA_WEBHOOK_VERIFY_TOKEN` | Token used to validate Strava's webhook subscription handshake |
| `APP_HOST` | Public domain (e.g. `a-runners-diary.fly.dev`) — used to build the Strava webhook callback URL |
| `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY` | Web Push keys. Generate once with `bin/rails runner "k = WebPush.generate_key; puts k.public_key; puts k.private_key"` |

Athlete-level secrets (Claude API key, Strava access/refresh tokens) are
stored encrypted in the database per-user, not as env vars.

## Deployment (Fly.io)

```bash
fly launch       # first time only, creates the app from fly.toml
fly secrets set VAPID_PUBLIC_KEY=... VAPID_PRIVATE_KEY=...
fly deploy
```

`release_command` in `fly.toml` runs migrations automatically on deploy. The
Strava push subscription is created automatically the first time the app
boots in production (and self-heals daily) — no manual `curl` step needed
anymore.
