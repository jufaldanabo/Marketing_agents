# Marketing Agents Toolkit v2.1

**Multi-tenant marketing agency automation for Claude Code.**  
Covers the complete 6-phase agency workflow (diagnosis → brand → planning → production → publishing → monitoring) for B2B, B2C and both business models — nothing hardcoded, everything adapts to the client brief.

---

## What it is

A **Claude Code plugin** composed of:
- **14 specialized agents** (bounded contexts) operating via the Task tool
- **24 slash commands** as thin entry points
- **27 reusable skills** (atomic and composable)
- **3 JSON schemas** as contracts between components

Installable in any client repo via `install.sh`. Each repo has its own `.claude/client-brief.json` defining the client — **the toolkit is never modified between clients, only the brief changes**.

---

## Installation

### In a new client repo

```bash
cd /path/to/client-repo
bash <(curl -sL https://raw.githubusercontent.com/jufaldanabo/Marketing_agents/main/install.sh)
```

### From the cloned toolkit (dev)

```bash
cd ~/Marketing_agents
bash install.sh /path/to/client-repo
```

### After installing

```
1. /briefing new     → 10-15 min guided wizard — captures the full client brief
2. /setup-check      → validate all API credentials
3. /audit            → real baseline of accounts (adjusts unrealistic KPIs)
4. /brand-kit new    → extract visual identity
5. /optimize-profiles → align bios/links with objectives
```

---

## The 6-phase agency workflow

| Phase | What an agency does | Toolkit does it via |
|---|---|---|
| **1 — Diagnosis** | Client brief, account audit, buyer persona, KPIs | `/briefing new` + `/audit` |
| **2 — Brand** | Brand platform, visual identity, profile optimization | `/brand-kit new` + `/optimize-profiles` |
| **3 — Planning** | Monthly content calendar, optimal cadence | `/content-calendar` + `/trend-ranking` |
| **4 — Production** | Batch shooting plan, call sheets, post-production specs | `/production-plan` + `/batch-produce` |
| **5 — Publishing** | Scheduled posts, community management, paid media | `/publish-today` + `/community` + `/ads` |
| **6 — Monitoring** | 24h/72h/weekly/monthly performance vs KPIs | `/social-report` + `/report-monthly` |

---

## The 14 agents

| Agent | Phase | Model | Responsibility |
|---|---|---|---|
| `account-auditor` | 1 | opus | Audits accounts + competition, validates KPI realism |
| `brand-guardian` | 2 | opus | Extracts visual/verbal identity from client materials |
| `content-planner` | 3 | opus | Monthly calendar + optimal cadence calibration |
| `trend-analyst` | 3 | sonnet | Analyzes viral trends on YouTube + TikTok |
| `producer` | 4 | opus | Monthly batch shooting plan |
| `content-publisher` | 5 | opus | Multi-platform publishing (produce + publish modes) |
| `community-manager` | 5 | sonnet | Comments/DMs with FAQ + SLA + escalation |
| `paid-media` | 5 | opus | Meta Ads + TikTok Ads (never spends alone) |
| `social-monitor` | 6 | sonnet | Nightly report + crisis detection + token health |
| `performance-analyst` | 6 | opus | 24h/72h/weekly/monthly analysis vs KPIs |
| `conductor` | cross | opus | Meta-orchestrator — events, circuit breakers, scheduled publishing |
| `approval-gatekeeper` | infra | sonnet | Async approval lifecycle + Telegram trigger commands |
| `market-analyst` | aux | opus | Market intelligence (prices + public competition) |
| `sales-prospector` | aux B2B | opus | Commercial pipeline — B2B/both only |

---

## The 24 commands

### Orchestration
| Command | Description |
|---|---|
| `/daily` | Full daily flow — replaces running multiple commands manually |
| `/dashboard` | Consolidated executive view |
| `/pause-posting` | Manual circuit breaker — stops all publishing |
| `/resume-posting` | Lifts the pause |
| `/check-approvals` | Process pending Telegram approvals |
| `/retry-failed` | Recover failed operations |

### Phase 1 — Diagnosis
| Command | Description |
|---|---|
| `/briefing new\|update\|show\|validate` | Client brief (schema v2.0) |
| `/audit` | Account + competition audit |

### Phase 2 — Brand
| Command | Description |
|---|---|
| `/brand-kit new\|update\|show` | Visual and verbal identity |
| `/optimize-profiles` | Optimize bios, links, highlights |

### Phase 3 — Planning
| Command | Description |
|---|---|
| `/content-calendar` | Monthly content calendar |
| `/trend-ranking` | Content ideas based on YouTube + TikTok virals |

### Phase 4 — Production
| Command | Description |
|---|---|
| `/production-plan` | Monthly batch shooting plan |
| `/batch-produce` | Pre-generate and approve the full month (copy + images) |

### Phase 5 — Publishing
| Command | Description |
|---|---|
| `/publish-today` | Publish today's content (uses pre-produced drafts if available) |
| `/community` | Conversational community management |
| `/ads` | Paid media (Meta Ads + TikTok Ads) |
| `/respond-comments` | Respond to specific comments |

### Phase 6 — Monitoring
| Command | Description |
|---|---|
| `/social-report` | Nightly report |
| `/report-monthly` | Monthly report vs KPIs |
| `/market-intel` | Market intelligence |

### B2B Auxiliary
| Command | Description |
|---|---|
| `/prospect-leads` | Lead search and qualification |
| `/followup-leads` | Follow-up sequence |

### Infrastructure
| Command | Description |
|---|---|
| `/setup-check` | Credential validation |
| `/setup-railway` | Deploy as Railway cron jobs |
| `/security-audit` | Security audit |

---

## Telegram control (no CLI needed)

Once deployed on Railway, the client can control the system directly from Telegram — no Claude Code CLI required.

| Send to Telegram | What happens |
|---|---|
| `publicar hoy` / `publish today` | Triggers `content-publisher` immediately |
| `pausa` / `pause` | Pauses all publishing (creates lock) |
| `reanuda` / `resume` | Lifts the pause |
| `check` / `qué hay pendiente` | Replies with current status |
| `sí` / `ok` / `publicar` | Approves a pending draft |
| `editar: {instructions}` | Requests changes to a pending draft |
| `no` / `rechazar` | Rejects a draft |

The `approval-gatekeeper` polls Telegram every 10 minutes and classifies every message as either an approval response or a trigger command.

---

## Calendar-driven scheduling

When deployed on Railway, the `conductor` runs every hour and checks the approved calendar for entries scheduled at the current hour. If a match is found, it automatically spawns `content-publisher` — no manual intervention required.

Publishing time is set in the calendar when running `/content-calendar`.

---

## Railway deployment

Run `/setup-railway` from Claude Code to generate all deployment files (`scheduler.py`, `railway.toml`, `Dockerfile`).

Cron schedule (Colombia UTC-5, adjust to your timezone):

| Agent | Schedule | Local time |
|---|---|---|
| `content-publisher` | `0 13 * * 1-5` | Mon-Fri 08:00 |
| `conductor` | `0 * * * *` | Every hour |
| `approval-gatekeeper` | `*/10 * * * *` | Every 10 min |
| `social-monitor` | `0 3 * * *` | Daily 22:00 |
| `community-manager` | `0 */4 * * *` | Every 4h |
| `performance-analyst` | Multiple | 24h / 72h / weekly / monthly |
| `content-planner` | `0 14 25 * *` | Day 25 09:00 |
| `producer` | `0 14 20 * *` | Day 20 09:00 |

Estimated cost: ~$25-40/month on Railway Pro.

---

## Environment variables

| Variable | Required for | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Everything | Anthropic API key |
| `TELEGRAM_BOT_TOKEN` | Everything | Telegram bot token (from @BotFather) |
| `TELEGRAM_CHAT_ID` | Everything | Chat ID for alerts and approvals |
| `FAL_KEY` | Image generation | fal.ai API key — uses `google/nano-banana-2.1` |
| `INSTAGRAM_ACCESS_TOKEN` | IG publishing | Long-lived token (60 days) |
| `INSTAGRAM_BUSINESS_ACCOUNT_ID` | IG publishing | Business account ID |
| `FACEBOOK_ACCESS_TOKEN` | FB publishing | Page long-lived token |
| `FACEBOOK_PAGE_ID` | FB publishing | Facebook page ID |
| `FACEBOOK_APP_ID` | Token check | App ID for expiry verification |
| `FACEBOOK_APP_SECRET` | Token check | App secret for expiry verification |
| `TIKTOK_ACCESS_TOKEN` | TikTok | OAuth 2.0 token (24h expiry) |
| `TIKTOK_OPEN_ID` | TikTok | User open_id |
| `TIKTOK_CLIENT_KEY` | TikTok | Client key for token refresh |
| `TIKTOK_CLIENT_SECRET` | TikTok | Client secret for token refresh |
| `META_AD_ACCOUNT_ID` | Meta Ads | Only if `paid_media_monthly > 0` |
| `TIKTOK_ADVERTISER_ID` | TikTok Ads | Only if TikTok Ads enabled |

---

## Repo structure

```
Marketing_agents/
├── commands/          ← 24 slash commands (thin orchestrators)
├── agents/            ← 14 agents (bounded contexts)
├── skills/
│   ├── _core/         ← 6 foundational skills + 4 schemas
│   ├── publishing/    ← 9 skills (generate, publish per platform)
│   ├── social_monitoring/
│   ├── market_intelligence/
│   ├── prospecting/
│   ├── deployment/
│   └── security/
├── install.sh         ← multi-tenant installer
├── plugin.json        ← plugin manifest
└── CLAUDE.md          ← full toolkit documentation
```

When installed in a client repo:

```
client-repo/
├── .claude/
│   ├── client-brief.json    ← client config (v2.0)
│   ├── brand-kit.json       ← visual/verbal identity
│   ├── brand-images/        ← photos, logos, product catalog
│   ├── commands/            ← toolkit installed here
│   ├── agents/
│   ├── skills/
│   └── state/               ← operational state
├── .env                     ← credentials (gitignored)
└── README.md                ← auto-generated after /briefing new
```

---

## Models

| Task | Model |
|---|---|
| Creative / strategic generation | `claude-opus-4-7` with adaptive thinking |
| Analysis / synthesis / classification | `claude-sonnet-4-6` |
| Simple validations / intent classification | `claude-haiku-4-5` |
| Image generation | `google/nano-banana-2.1` via fal.ai |

---

## License

MIT
