# Product Spec — A Runner's Diary

## Vision

A training partner, not a generic plan generator. The athlete gives Claude
real context (who they are, how they're feeling, what they're eating, what
Strava says they actually did) and Claude adapts the plan continuously,
the way a real coach would. Plans default to demanding — this is for people
who want to be pushed, not babied.

## Users

Athletes (friends-and-family beta, invite-only for now) and one admin role
(the app owner) who can see all accounts.

## Onboarding flow

1. **Sign up** — email, first name, last name, password.
2. **Athlete profile** — age, sex, height, and a free-text paragraph for
   injuries / context / anything the athlete wants Claude to know. Only
   asked once; editable later from settings.
3. **Race goal** — distance (5K / 10K / Half Marathon / Marathon / Hyrox),
   date, target time, difficulty level (Beginner / Intermediate / Advanced),
   and optional strength/bodyweight training frequency (None / 1-2x /
   3-4x / 5+x per week) for runners who also want to lift. One active race
   at a time. Hyrox is a hybrid race (running + 8 functional stations) —
   the coach knows the format and mixes strength and station-specific
   conditioning into the plan regardless of the frequency setting.
4. **Connect Strava** — OAuth authorization, required before the Claude key
   step. We pull recent activity history immediately after connecting to
   assess current fitness level, so the very first coach summary is
   already informed by real training data instead of starting blind.
5. **Get the app** — install to home screen + enable push notifications,
   right after the race goal (step 3 of 3) and before reaching the
   dashboard — not buried as a dashboard afterthought. Deliberately placed
   *after* the athlete has stated their goal (so the permission prompt has
   context: "you'll be notified when your coach reacts to your training")
   rather than before onboarding, which tends to get worse grant rates.
   This also means notifications are live in time for the very first
   "your training program is ready" push, not just later ones.
6. **Connect Strava** — OAuth authorization, required before the Claude key
   step. We pull recent activity history immediately after connecting to
   assess current fitness level, so the very first coach summary is
   already informed by real training data instead of starting blind.
7. **Add Claude API key** — athlete pastes their own Anthropic API key.
   Stored encrypted, never shown again in full (masked after entry).
8. Program generation kicks off — first call to Claude using all of the
   above context, producing both the weekly roadmap and the first two
   weeks of daily detail (see below).

## Daily experience (dashboard)

- **Current week summary** — phase (base/build/peak/taper/race week) and
  weekly distance target, linking to the full roadmap.
- **Today's workout** from the active training program.
- **Macro/nutrition suggestion** for the day, derived from the workout
  load and recent intake.
- **Claude's latest opinion** — a short written summary of how training is
  going (on track / behind / ahead, and why).
- **Log a meal** — calories + macros (protein/carbs/fat), free-text notes.
  Manual entry only for v1.
- **Chat with Claude** — free-text conversation. The athlete can say "my
  knee hurts" or "I felt great today" and Claude can react and adjust —
  and this conversation is now part of what every future adaptation sees,
  not just a side channel.

## Race roadmap

A dedicated page (linked from the nav and the dashboard's current-week
card) showing every week from today to race day: phase, date range,
target weekly distance, and a one-line focus, with the current week
highlighted. Generated once alongside the initial program and
automatically extended if it ever falls short of race day. Day-by-day
detail is deliberately *not* shown this far out — only the next ~2 weeks
have real daily workouts at any time, since the specifics further out are
going to be rewritten anyway once there's real performance data for that
week. The roadmap is the answer to "can I see my whole training block to
race day" without paying for daily detail that won't survive contact with
reality.

## Adaptation loop

- Strava webhook fires on a new activity → app fetches the activity →
  sends it to Claude along with current program state → Claude responds
  with an updated opinion and, if needed, adjustments to upcoming days.
- If a scheduled day passes with no matching Strava activity, a daily job
  flags it as skipped and asks Claude to re-adapt the rest of the week.
- Nutrition logs feed into the same context window so Claude can comment
  ("you're under-fueling for the volume this week, eat more carbs
  Tuesday/Thursday").

## Difficulty levels

- **Beginner** — conservative volume ramp, more rest days, lower intensity.
- **Intermediate** — moderate volume, standard periodization.
- **Advanced** — high volume (5-6 sessions/week), demanding mindset,
  Claude is instructed to push the athlete rather than play it safe.

The difficulty is athlete-chosen at race setup, not auto-assigned — but
Claude's plan and tone should reflect it (e.g. an Advanced athlete should
never get a "take it easy" plan unless Strava/nutrition data shows signs of
overtraining or injury risk).

## Admin panel

- List all athletes, their active race, last activity sync date.
- View an athlete's profile, program, and Claude conversation (for
  debugging during the friends-and-family phase).
- Manually edit a customer's coach summary, or send them a custom push
  notification — both with honest feedback (e.g. "nothing sent, this
  athlete has no active subscription") rather than a false success message.
- No billing in v1 (the app is free for now).

## Explicitly out of scope for v1

- Payments / subscriptions
- Public sign-up (invite-only)
- Multiple simultaneous race goals
- Automated nutrition tracking integrations (MyFitnessPal etc.) — manual
  entry only
- Native App Store/Play Store app — installable PWA (push-capable, no
  native binary) only
