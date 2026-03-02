# Marketing Agents
**Social media marketing automation for small and medium businesses.**
This plugin provides skills, agents and commands for publishing B2B content,
monitoring social activity, tracking competitors and prospecting leads — all from Claude Code.

## Installation

```bash
# In your project directory:
bash <(curl -sL https://raw.githubusercontent.com/TU_USUARIO/Marketing_agents/main/install.sh)
```

Then run `/init` to configure your company and get started.

---

## Day-to-Day Usage

The plugin follows a simple loop: **configure → publish → monitor → grow**.

### First time setup
```
/init              → Interactive wizard: company context, ICP, credentials guide
/setup-check       → Validate all API connections and token expiry
```

### Daily publishing
```
/publish-today                    → Generate and publish B2B content (Instagram + Facebook)
/publish-today "tema específico"  → Publish about a specific topic
/check-approvals                  → Publish drafts approved by manager via Telegram
```

### Nightly monitoring
```
/social-report     → Metrics, comments and DMs summary sent to Telegram
/respond-comments  → Generate and publish replies to pending comments
```

### Weekly growth
```
/market-intel      → Commodity prices + competitor activity report
/prospect-leads    → Search and qualify new B2B leads
/followup-leads    → Send follow-up messages to non-responsive leads
```

### Deployment & maintenance
```
/setup-railway     → Deploy agents as cron jobs on Railway
/security-audit    → Audit credentials and security practices before deploying
```

---

## Typical workflow in one session

```bash
# Morning: content day
/init                           → Configure company (first time only)
/setup-check                    → Confirm all tokens are valid
/publish-today "nueva línea"    → Generate + preview + publish
/check-approvals                → Publish yesterday's pending approvals

# Evening: check activity
/social-report                  → What happened today?
/respond-comments               → Reply to commercial and urgent comments

# Weekly: grow the pipeline
/market-intel                   → Any price changes or competitor moves?
/prospect-leads                 → Find 10 new leads in target sector
/followup-leads                 → Follow up on leads from last week
```

---

## Skills

| Skill | Description | Key Commands |
|---|---|---|
| `publishing` | B2B content generation for Instagram, Facebook, TikTok. Approval workflow via Telegram | `/publish-today`, `/check-approvals` |
| `social-monitoring` | Comments analysis, metrics, token expiry alerts, Telegram notifications | `/social-report`, `/respond-comments` |
| `market-intel` | Commodity price tracking and public competitor activity monitoring | `/market-intel` |
| `prospecting` | Lead search (ICP-based), scoring 0-100, outreach messages, multi-touch follow-up | `/prospect-leads`, `/followup-leads` |

---

## Agents

| Agent | Description |
|---|---|
| `content-publisher` | Generates daily B2B content adapted per platform and publishes via Meta and TikTok APIs |
| `social-monitor` | Reads comments, DMs and metrics; alerts via Telegram; checks Meta token expiry |
| `market-analyst` | Tracks commodity prices and competitor social activity; generates strategic reports |
| `sales-prospector` | Searches leads using public sources, qualifies them, generates personalized outreach |

---

## Commands

### Setup
| Command | Description |
|---|---|
| `/init` | Interactive onboarding wizard — company, ICP, credentials guide. Generates `company-context.json` and `.env.example` |
| `/setup-check` | Validates all API connections (Instagram, Facebook, TikTok, Telegram). Checks token expiry |
| `/setup-railway` | Deploys all agents as scheduled cron jobs on Railway |
| `/security-audit` | Audits credentials, `.env` handling, permissions and security practices |

### Publish
| Command | Description |
|---|---|
| `/publish-today` | Generates B2B content and publishes to Instagram and Facebook (with preview before posting) |
| `/check-approvals` | Polls Telegram for manager responses and publishes approved drafts |

### Monitor
| Command | Description |
|---|---|
| `/social-report` | Nightly report: metrics, comments and DMs summary sent to Telegram |
| `/respond-comments` | Reads pending comments, generates replies by type, publishes after preview |

### Grow
| Command | Description |
|---|---|
| `/market-intel` | Weekly commodity prices + competitor activity + strategic recommendations |
| `/prospect-leads` | Searches and qualifies B2B leads based on ICP. Generates personalized outreach messages |
| `/followup-leads` | Multi-touch follow-up for non-responsive leads. Handles positive responses with catalog messages |

---

## Environment variables

Copy `.env.example` to `.env` and fill in the values. Run `/init` for a guided setup.

| Variable | Required | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | ✅ All | Anthropic API key |
| `COMPANY_NAME` | ✅ All | Company name |
| `INDUSTRY` | ✅ All | Industry sector (e.g. textil, manufactura) |
| `TELEGRAM_BOT_TOKEN` | ✅ All | Telegram bot token (from @BotFather) |
| `TELEGRAM_CHAT_ID` | ✅ All | Telegram chat ID for alerts |
| `INSTAGRAM_ACCESS_TOKEN` | 📸 Publishing | Instagram Graph API long-lived token (60 days) |
| `INSTAGRAM_BUSINESS_ACCOUNT_ID` | 📸 Publishing | Instagram business account ID |
| `FACEBOOK_ACCESS_TOKEN` | 📘 Publishing | Facebook page long-lived token |
| `FACEBOOK_PAGE_ID` | 📘 Publishing | Facebook page ID |
| `FACEBOOK_APP_ID` | 🔑 Token check | App ID for token expiry verification |
| `FACEBOOK_APP_SECRET` | 🔑 Token check | App secret for token expiry verification |
| `TIKTOK_ACCESS_TOKEN` | 🎵 Optional | TikTok OAuth 2.0 token (scope: `video.publish`) |
| `TIKTOK_OPEN_ID` | 🎵 Optional | TikTok user `open_id` |
| `SENDER_NAME` | 📬 Prospecting | Salesperson name for outreach messages |
| `SENDER_ROLE` | 📬 Prospecting | Salesperson role/title |

---

## Key References

| File | Description |
|---|---|
| `commands/init.md` | Onboarding wizard — collects all company context interactively |
| `commands/setup-check.md` | Credential and connection validation guide |
| `agents/publisher-agent.md` | Content publisher system prompt |
| `agents/prospecting-agent.md` | Sales prospector system prompt |
| `skills/publishing/content-approval.md` | Telegram approval workflow for content drafts |
| `skills/prospecting/handle-positive-response.md` | Lead positive response handling |
| `skills/social_monitoring/check-token-expiry.md` | Meta API token expiry monitoring |
| `skills/publishing/publish-tiktok.md` | TikTok Content Posting API |

---

## License

MIT
