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
3. **Race goal** — distance (5K / 10K / Half Marathon / Marathon), date,
   target time, difficulty level (Beginner / Intermediate / Advanced).
   One active race at a time.
4. **Connect Strava** — OAuth authorization. We pull recent activity history
   immediately after connecting to assess current fitness level.
5. **Add Claude API key** — athlete pastes their own Anthropic API key.
   Stored encrypted, never shown again in full (masked after entry).
6. Program generation kicks off — first call to Claude using all of the
   above context.

## Daily experience (dashboard)

- **Today's workout** from the active training program.
- **Macro/nutrition suggestion** for the day, derived from the workout
  load and recent intake.
- **Claude's latest opinion** — a short written summary of how training is
  going (on track / behind / ahead, and why).
- **Log a meal** — calories + macros (protein/carbs/fat), free-text notes.
  Manual entry only for v1.
- **Chat with Claude** — free-text conversation. The athlete can say "my
  knee hurts" or "I felt great today" and Claude can react and adjust.

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
- No billing in v1 (the app is free for now).

## Explicitly out of scope for v1

- Payments / subscriptions
- Public sign-up (invite-only)
- Multiple simultaneous race goals
- Automated nutrition tracking integrations (MyFitnessPal etc.) — manual
  entry only
- Mobile app — responsive web only
