# Technical Spec — A Runner's Diary

## Stack

Rails 7.2 (monolith, Hotwire, no API/SPA split), PostgreSQL, Solid Queue for
background jobs (DB-backed, avoids running Redis on Fly.io), Devise for
auth, Tailwind for styling, Faraday for outbound HTTP (Strava + Anthropic).

## Data model

```
User
  email, encrypted_password, first_name, last_name, role (athlete|admin)
  has_one :athlete_profile
  has_one :claude_credential
  has_one :strava_connection
  has_one :race                (one active race at a time, v1)
  has_many :nutrition_logs
  has_many :messages            (chat with Claude)

AthleteProfile
  belongs_to :user
  age:integer, sex:string, height_cm:integer
  notes:text                    # free-text, read by Claude as context

ClaudeCredential
  belongs_to :user
  api_key:string  (encrypted via Rails 7 `encrypts`)

StravaConnection
  belongs_to :user
  strava_athlete_id:bigint
  access_token:string (encrypted), refresh_token:string (encrypted)
  expires_at:datetime

Race
  belongs_to :user
  race_type:string   # 5k | 10k | half_marathon | marathon
  race_date:date
  time_objective:string   # e.g. "01:50:00"
  difficulty:string  # beginner | intermediate | advanced
  has_one :training_program

TrainingProgram
  belongs_to :race
  status:string  # active | superseded
  generated_at:datetime
  claude_summary:text        # latest "opinion" shown on dashboard
  has_many :training_days

TrainingDay
  belongs_to :training_program
  date:date
  workout:text                # human-readable description
  status:string  # pending | completed | skipped

StravaActivity
  belongs_to :user
  strava_id:bigint, raw_data:jsonb
  claude_analysis:text
  occurred_at:datetime

NutritionLog
  belongs_to :user
  date:date, calories:integer
  protein_g:integer, carbs_g:integer, fat_g:integer
  notes:text

Message
  belongs_to :user
  role:string  # user | assistant
  content:text
```

Secrets (`api_key`, `access_token`, `refresh_token`) use Rails'
`encrypts` (ActiveRecord Encryption, built into Rails 7) backed by
`config/credentials.yml.enc`. Never logged, never returned in JSON.

## Strava integration

One Strava API application registered by the app owner
(`STRAVA_CLIENT_ID` / `STRAVA_CLIENT_SECRET`, app-level env vars). Each
athlete authorizes that single app via standard OAuth2:

1. `GET /strava/connect` → redirect to Strava's authorize URL with scope
   `activity:read_all`.
2. Strava redirects back to `GET /strava/callback?code=...` → exchange code
   for access/refresh tokens → store on `StravaConnection`.
3. One webhook subscription for the whole app (Strava only allows one per
   application) receives `create`/`update` events for *all* authorized
   athletes. `POST /strava/webhook` validates the event, enqueues
   `Strava::ProcessActivityJob` with the athlete + activity id.
4. The job fetches the full activity via the athlete's access token
   (refreshing it first if expired — refresh tokens don't expire,
   access tokens last ~6h), stores it as `StravaActivity`, then enqueues
   `Coach::ReactToActivityJob` to ask Claude for an updated opinion.
5. A daily scheduled job (`Coach::CheckMissedDaysJob`) walks
   `TrainingDay` rows with no matching activity past their date and marks
   them `skipped`, then triggers re-adaptation.

## Claude integration

`Coach::Client` wraps Faraday calls to the Anthropic Messages API using
the athlete's own `ClaudeCredential#api_key` — never an app-level key.
Three entry points, all building a context-rich prompt:

- `Coach::GenerateProgram` — builds the initial `TrainingProgram` +
  `TrainingDay` rows from profile + race + recent Strava history.
- `Coach::ReactToActivity` — given a new `StravaActivity` (or a skipped
  day), asks Claude to update `claude_summary` and optionally rewrite
  upcoming `TrainingDay#workout` entries.
- `Coach::Chat` — free-form conversation; appends to `Message` history and
  includes recent program/activity/nutrition context in the system prompt.

All three share a `Coach::ContextBuilder` that assembles: athlete profile
notes, current race goal + difficulty, last N Strava activities (pace,
distance, duration, heart rate if present), last N nutrition logs, and
current program state. This keeps the "what does Claude know" logic in one
place instead of duplicated per call site.

If an athlete's Claude key is missing/invalid, dashboard actions that need
Claude show an inline error asking them to add a valid key in settings —
the rest of the app (Strava sync, manual logging) keeps working.

## Background jobs (Solid Queue)

- `Strava::ProcessActivityJob`
- `Coach::ReactToActivityJob`
- `Coach::GenerateProgramJob`
- `Coach::CheckMissedDaysJob` (scheduled daily via `config/recurring.yml`)

## Routing sketch

```
/users/sign_up, /users/sign_in        (Devise)
/onboarding/profile
/onboarding/race
/strava/connect, /strava/callback, /strava/webhook
/settings/claude_credential
/dashboard
/nutrition_logs
/messages
/admin/users, /admin/users/:id
```

## Docker / Fly.io

Mirrors `dev/tix-tracker`: multi-stage `Dockerfile` for production,
`Dockerfile.dev` + `docker-compose.yml` for local dev with a Postgres
service, `fly.toml` with `release_command = "bin/rails db:migrate"` and
`auto_stop_machines` for cost control. Solid Queue runs in-process via
Puma plugin (`SOLID_QUEUE_IN_PUMA=true`) for v1 to avoid a second Fly
machine — revisit if job volume grows.

## Open items for later iterations (not v1)

- Rate/cost limits on Claude usage per athlete (their own key, but the app
  should not let a runaway loop drain it).
- Strava webhook signature/IP validation hardening beyond the verify token.
- Multi-race support.
