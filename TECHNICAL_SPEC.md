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
  timezone:string               # ActiveSupport::TimeZone name, used for the 9am check-in
  last_daily_checkin_on:date    # idempotency marker for the hourly sweep
  review_on_chat:boolean        # opt-in: re-adapt plan after every chat message
  review_on_nutrition_log:boolean # opt-in: re-adapt plan after every nutrition log

PushSubscription
  belongs_to :user
  endpoint:text (unique), p256dh:string, auth:string   # one row per subscribed browser/device

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
  race_type:string   # 5k | 10k | half_marathon | marathon | hyrox
  race_date:date
  time_objective:string   # e.g. "01:50:00"
  difficulty:string  # beginner | intermediate | advanced
  strength_training_frequency:string  # none | 1_2_per_week | 3_4_per_week | 5_plus_per_week
  has_one :training_program

TrainingProgram
  belongs_to :race
  status:string  # active | superseded
  generated_at:datetime
  claude_summary:text        # latest "opinion" shown on dashboard
  has_many :training_days
  has_many :training_weeks

TrainingWeek
  belongs_to :training_program
  week_number:integer (unique per program)
  start_date:date, end_date:date
  phase:string   # base | build | peak | taper | race_week
  target_distance_km:integer
  focus:text                 # one-line description shown on the roadmap page
  # Generated once for the full span to race day (GenerateProgram, capped at
  # MAX_ROADMAP_WEEKS=30), extended by ReactToActivity if it ever falls short
  # of race day. Daily detail (TrainingDay) stays lazily generated/extended
  # as before — only the lightweight phase/volume roadmap covers the full
  # horizon upfront.

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
athlete authorizes that single app via standard OAuth2.

Strava must be connected *before* adding a Claude key —
`ClaudeCredentialsController` has a `require_strava_connection`
before_action on `new`/`create` (not `edit`/`update`, so it never locks
out someone who already has a key) that redirects back to the dashboard
otherwise. This isn't just onboarding polish: `Coach::GenerateProgram` is
triggered the moment a Claude key is saved, and `Coach::ContextBuilder`
reads `user.strava_activities` at that moment — connecting Strava first
means the activity backfill (`Strava::SyncActivitiesJob`, enqueued from
the OAuth callback) has already run by the time the athlete manually
navigates to add their key, so the *first* coach summary is informed by
real training data instead of generating blind and needing a second call
to catch up.

1. `GET /strava/connect` → redirect to Strava's authorize URL with scope
   `activity:read_all`.
2. Strava redirects back to `GET /strava/callback?code=...` → exchange code
   for access/refresh tokens → store on `StravaConnection` → enqueues
   `Strava::SyncActivitiesJob` to immediately backfill recent history
   (same job as the manual "sync now" button below).
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
6. `Strava::EnsureWebhookSubscription` checks (`GET`) before creating
   (`POST`) — Strava allows exactly one subscription per app, so this is
   safe to call repeatedly. It runs once async on `rails server` boot
   (guarded by `defined?(Rails::Server)` so it never fires for rake tasks,
   console, or the migration release step) and again daily as a self-heal
   sweep, in case the subscription is ever deleted on Strava's side.
7. `Strava::SyncActivities` (`Strava::Client#list_activities`, most recent
   30) backs both the auto-backfill on connect and the dashboard's manual
   "sync now" button (`POST /strava_sync`) — catch-up if a webhook event
   was ever missed. It dedupes against existing `StravaActivity#strava_id`
   rows and fires **at most one** `Coach::ReactToActivityJob` for the whole
   batch, not one per activity — a backfill can pull in dozens of
   activities at once, and reacting to each individually would multiply
   Claude cost and could fire a flurry of push notifications for old
   history.

## Adaptation triggers

`Coach::ReactToActivityJob` is the single entry point for "something
happened, re-check the plan." It's triggered by:

- A new Strava activity (always on — `Strava::ProcessActivityJob`).
- A missed training day (always on — nightly `Coach::CheckMissedDaysJob`).
- A chat message (opt-in, `AthleteProfile#review_on_chat`).
- A nutrition log (opt-in, `AthleteProfile#review_on_nutrition_log`).
- The athlete's local 9am, every day — **but only if `TrainingProgram#review_worthwhile?`**.
- Tapping "Check for updates" on the dashboard (`StravaSyncsController` →
  `Strava::SyncActivities`) — same `review_worthwhile?` gate.

The two opt-in triggers default to `false` — every chat message or meal log
triggering a Claude call multiplies cost and can make the plan feel like
it's changing too often. Athletes turn them on in
`/onboarding/profile/edit` if they want a more reactive coach.

### Don't review when there's nothing to review

The first version of the daily check-in and the manual button both called
`Coach::ReactToActivity` unconditionally — with no new Strava activity or
nutrition log to react to, Claude had nothing to say except a low-value
"you gave me nothing to work with" message, which **overwrote** a
perfectly good existing `claude_summary`. The fix is
`TrainingProgram#review_worthwhile?` = `new_data_since_last_review?` (any
`StravaActivity`/`NutritionLog` created after `claude_summary` was last
written) `|| needs_extending?` (fewer than `MIN_PENDING_DAYS_BUFFER`
pending days left — the schedule itself can need topping up independent
of whether anything "happened"). Triggers that are *themselves* new
information (a Strava activity arriving, a chat message, a nutrition log)
skip this gate — they're inherently worth reacting to. Only the two
triggers that fire on a timer/on click without their own justification
(daily check-in, manual button) are gated by it.

### Per-athlete daily check-in (no per-user cron)

There's no per-user cron in Solid Queue's recurring scheduler — it's one
static schedule for the whole app. `Coach::DailyCheckInSweepJob` runs every
hour instead: each athlete's local hour advances by exactly one every time
the sweep runs, so it crosses their local 9am exactly once per day. The
job checks `AthleteProfile#local_hour_now == 9` and
`AthleteProfile#checked_in_today?` (backed by `last_daily_checkin_on`) to
fire exactly once and skip everyone else, then `review_worthwhile?` to
decide whether to actually call Claude. An athlete with no `timezone` set
falls back to UTC (`AthleteProfile#time_zone`) rather than being skipped.

## Claude integration

`Coach::Client` wraps Faraday calls to the Anthropic Messages API using
the athlete's own `ClaudeCredential#api_key` — never an app-level key.
Three entry points, all building a context-rich prompt:

- `Coach::GenerateProgram` — builds, in one call: (1) a `TrainingWeek`
  roadmap covering every week from today to race day (phase + weekly
  distance target + one-line focus — base → build → peak → taper →
  race_week, capped at `MAX_ROADMAP_WEEKS` = 30 for very long lead times),
  and (2) detailed `TrainingDay` rows for only the first
  `PLANNING_HORIZON_DAYS` (14) days, starting **today** (not tomorrow — an
  earlier version left day one permanently empty on the dashboard).
  Daily detail is intentionally NOT generated for the full horizon
  upfront — those days are going to be rewritten anyway once real
  performance data exists for them, so committing to exact workout text
  months out is wasted effort. The roadmap is cheap (one row per week) and
  gives the "see the whole journey to race day" view without that cost.
- `Coach::ReactToActivity` — given a new `StravaActivity` (or a skipped
  day), asks Claude to update `claude_summary`, optionally rewrite
  upcoming `TrainingDay#workout` entries (`updates`), schedule new days
  (`additions`) once fewer than `MIN_PENDING_DAYS_BUFFER` (5) pending days
  remain (keeping `EXTEND_TO_DAYS` (10) days of runway), and extend the
  weekly roadmap (`week_additions`) if `TrainingProgram#roadmap_incomplete?`
  (last week's `end_date` is before race day — e.g. the initial 30-week
  cap was hit). This is the *only* refill mechanism for both the daily
  schedule and the roadmap: every trigger (Strava sync, daily 9am
  check-in, manual "check for updates", opt-in chat/nutrition triggers)
  shares this one code path, so both top themselves up automatically
  instead of running dry after `GenerateProgram`'s initial window.
- `Coach::Chat` — free-form conversation; appends to `Message` history and
  includes recent program/activity/nutrition context in the system prompt.

All three share a `Coach::ContextBuilder` that assembles: athlete profile
notes, current race goal + difficulty, the full weekly roadmap (with the
current week flagged), the next 7 days of daily detail, last N Strava
activities (pace, distance, duration, heart rate if present), last N
nutrition logs, and last N chat messages (in actual chronological order —
an earlier version built history with `.order(desc).limit(n).order(asc)`,
which doesn't re-sort a limited set, it just appends a second, dead ORDER
BY clause to the same query; fixed to fetch-then-`.reverse` in Ruby, used
in both `Coach::Chat` and here). This keeps the "what does Claude know"
logic in one place instead of duplicated per call site.

If an athlete's Claude key is missing/invalid, dashboard actions that need
Claude show an inline error asking them to add a valid key in settings —
the rest of the app (Strava sync, manual logging) keeps working.

## Push notifications (PWA)

`PushNotificationService.notify(user, title:, body:)` sends a Web Push
message to every `PushSubscription` a user has, using free VAPID-based
push (no APNs/FCM account, no per-message cost) via the `web-push` gem.
Fired once, in v1, on "new coach summary ready" — inside
`Coach::GenerateProgram` and `Coach::ReactToActivity` after
`claude_summary` is updated. A delivery failure (expired subscription,
malformed keys, network error) is always caught and logged inside
`PushNotificationService` — it must never bubble up into the calling
Coach service, since the notification is a side effect and the plan
update is the part that actually matters.

Subscribing happens client-side: `app/javascript/controllers/push_subscription_controller.js`
registers `app/views/pwa/service-worker.js`, requests notification
permission, subscribes via `PushManager`, and posts the subscription
(`endpoint`/`p256dh`/`auth`) to `PushSubscriptionsController`. The VAPID
public key is injected into the dashboard via
`Rails.application.config.x.vapid_public_key` (set from `VAPID_PUBLIC_KEY`
in `config/initializers/web_push.rb`); the matching private key never
leaves the server.

iOS Safari only supports push for a PWA added to the home screen (no
native install prompt like Android) — `ios_install_nudge_controller.js`
shows a one-line banner with "Share → Add to Home Screen" instructions,
detected via `navigator.standalone` / `matchMedia("(display-mode: standalone)")`,
shown only to iOS Safari users who haven't installed it yet.

## Background jobs (Solid Queue)

- `Strava::ProcessActivityJob`
- `Strava::EnsureWebhookSubscriptionJob` (boot-time + daily self-heal)
- `Strava::SyncActivitiesJob` (on connect + manual "sync now" button)
- `Coach::ReactToActivityJob`
- `Coach::GenerateProgramJob`
- `Coach::CheckMissedDaysJob` (scheduled daily via `config/recurring.yml`)
- `Coach::DailyCheckInSweepJob` (scheduled hourly; fires per-athlete at
  their local 9am — see Adaptation triggers above)

## Routing sketch

```
/users/sign_up, /users/sign_in        (Devise)
/onboarding/profile
/onboarding/race
/onboarding/app_setup                 (step 3 — install + notifications, first-time race creation only)
/strava/connect, /strava/callback, /strava/webhook
/settings/claude_credential
/dashboard
/roadmap                              (weekly periodization view)
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
