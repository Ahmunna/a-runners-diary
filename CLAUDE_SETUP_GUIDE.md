# Setting up your Claude API key

A Runner's Diary uses Claude (from Anthropic) to build and adapt your training
program. Each athlete connects their **own** Claude API key — this is a
different thing from a ChatGPT/Claude.ai subscription, so the steps below
walk through it.

## Why you need this

The app doesn't come with Claude built in. You bring your own key so that:
- Your coaching conversations and training data go through *your* account, not a shared one.
- You only ever pay for what you actually use — no markup, no subscription to us.

## Step 1 — Create an Anthropic account

1. Go to [console.anthropic.com](https://console.anthropic.com) and sign up (or log in if you already have an account).
2. This is **not** the same as a claude.ai login — claude.ai is the chat app, console.anthropic.com is the developer/billing side that issues API keys.

## Step 2 — Add billing

1. In the Console, go to **Settings → Billing**.
2. Add a payment method and purchase credits (a small initial amount, e.g. $5–10, is plenty to start).
3. Optional but recommended: under **Settings → Limits**, set a **monthly spend limit** so you can't be surprised by a bill — see cost estimate below for a sensible number to set.

## Step 3 — Create your API key

1. Go to **Settings → API Keys**.
2. Click **Create Key**, give it any name (e.g. "Runner's Diary").
3. Copy the key — it starts with `sk-ant-...`. You won't be able to see the full key again after this, so copy it now.

## Step 4 — Add it to A Runner's Diary

1. Log into the app, go to **Settings** in the top navigation.
2. Paste your key into the **Claude API key** field and save.
3. That's it — your coach will generate your training program shortly after.

If your key is ever invalid or runs out of credits, the app will keep working
for everything else (logging, nutrition, viewing your plan) and show a banner
telling you to fix your key.

## What will this cost?

There's no subscription and no free tier on the Claude API — it's pay only
for what you use, billed per "token" (roughly, per word processed). For how
this app actually uses Claude — generating your plan every couple of weeks,
reacting to synced activities, and the occasional chat message — realistic
usage works out to **roughly $2–4 per month** for a normal, active user.

It can run higher if you chat with your coach a lot or skip training days
often (each skipped day triggers a plan review). Setting a monthly spend
limit in Step 2 is the easiest way to make sure you never get a surprise.

You can check what you've actually spent any time at
**console.anthropic.com → Settings → Usage**.
