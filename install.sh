#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Marketing Agents Plugin v2.0 — Installer
#
# Multi-tenant marketing automation toolkit for Claude Code.
# Covers the full 6-phase agency flow: diagnosis, branding, planning,
# production, publishing, monitoring.
#
# Usage (from cloned repo):
#   bash install.sh
#   bash install.sh /path/to/target-project
#
# Usage (one-liner — replace jufaldanabo with the actual GitHub user):
#   bash <(curl -sL https://raw.githubusercontent.com/jufaldanabo/Marketing_agents/main/install.sh)
# ─────────────────────────────────────────────────────────────────────────────
set -e

REPO_RAW="https://raw.githubusercontent.com/jufaldanabo/Marketing_agents/main"
TARGET="${1:-$(pwd)}"
CLAUDE_DIR="$TARGET/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"
STATE_DIR="$CLAUDE_DIR/state"

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; RESET="\033[0m"
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}·${RESET} $1"; }
info() { echo -e "  ${CYAN}ℹ${RESET} $1"; }

# ── Artifact inventories ─────────────────────────────────────────────────────

COMMANDS=(
  # Phase 1 — Diagnosis
  briefing audit
  # Phase 2 — Brand
  brand-kit optimize-profiles
  # Phase 3 — Planning
  content-calendar
  # Phase 4 — Production
  production-plan
  # Phase 5 — Publishing / Community / Ads
  publish-today community ads respond-comments
  # Phase 6 — Monitoring + Trend analysis
  social-report report-monthly market-intel trend-ranking
  # Orchestration
  daily dashboard pause-posting resume-posting
  # Approvals
  check-approvals
  # Sales (auxiliary)
  prospect-leads followup-leads
  # Infrastructure
  setup-check setup-railway security-audit retry-failed
  # Plugin manager
  plugin
)

AGENTS=(
  content-planner-planner-agent     # file: planner-agent.md
  content-publisher-publisher-agent # file: publisher-agent.md
  social-monitor-monitoring-agent   # file: monitoring-agent.md
  market-analyst-intelligence-agent # file: intelligence-agent.md
  sales-prospector-prospecting-agent # file: prospecting-agent.md
  brand-guardian conductor approval-gatekeeper
  account-auditor community-manager paid-media performance-analyst producer
)

# Actual filenames (some agents have alternate file names from v1.0 legacy)
AGENT_FILES=(
  planner-agent.md publisher-agent.md monitoring-agent.md
  intelligence-agent.md prospecting-agent.md
  brand-guardian.md conductor.md approval-gatekeeper.md
  account-auditor.md community-manager.md paid-media.md
  performance-analyst.md producer.md trend-analyst-agent.md
)

SKILLS=(
  # Core (6)
  _core/load-brief _core/load-brand-kit _core/state-store
  _core/telegram-approval _core/telegram-notify _core/preflight-check
  _core/schemas/client-brief.schema _core/schemas/brand-kit.schema
  _core/schemas/kpi-tracking.schema _core/schemas/state-structure
  # Publishing (9)
  publishing/generate-content publishing/generate-image-ai
  publishing/generate-carousel publishing/generate-reel
  publishing/generate-tiktok-content publishing/publish-instagram
  publishing/publish-facebook publishing/publish-tiktok
  publishing/optimize-profile
  # Social monitoring (2)
  social_monitoring/respond-comments social_monitoring/check-token-expiry
  # Market intelligence (2)
  market_intelligence/monitor-prices market_intelligence/track-competitors
  # Prospecting (5)
  prospecting/search-leads prospecting/qualify-leads
  prospecting/outreach-message prospecting/follow-up-sequence
  prospecting/handle-positive-response
  # Deployment & security (2)
  deployment/schedule-railway security/validate-security
  # Trend analysis (5) — PR #1 integrated into v2.0
  trend_analysis/fetch-youtube-trends trend_analysis/fetch-tiktok-trends
  trend_analysis/analyze-trend-content trend_analysis/build-trend-report
  trend_analysis/generate-trend-ideas
)

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}Marketing Agents v2.0 — Multi-tenant Marketing Toolkit${RESET}"
echo "  Target: $TARGET"
echo ""

# ── Create directory structure ────────────────────────────────────────────────
mkdir -p "$COMMANDS_DIR" "$AGENTS_DIR" "$SKILLS_DIR" "$STATE_DIR"
mkdir -p "$STATE_DIR"/{calendar,posts,drafts,approvals,reports,intel,leads,followups,locks,handoffs,logs,audits,community,ads,performance,production,dashboards,insights,profile-optimization}
mkdir -p "$CLAUDE_DIR/brand-images/products"

# ── Detect local vs remote mode ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_MODE=false
if [ -d "$SCRIPT_DIR/commands" ] && ls "$SCRIPT_DIR/commands"/*.md &>/dev/null 2>&1; then
  LOCAL_MODE=true
  info "Local mode: copying from $SCRIPT_DIR"
else
  info "Remote mode: downloading from GitHub"
  command -v curl &>/dev/null || { echo "curl is required for remote install"; exit 1; }
fi

# ── Helper: copy or download a file ──────────────────────────────────────────
install_file() {
  local src_path="$1"
  local dst_path="$2"
  local label="$3"

  mkdir -p "$(dirname "$dst_path")"

  if [ "$LOCAL_MODE" = true ]; then
    if [ -f "$SCRIPT_DIR/$src_path" ]; then
      cp "$SCRIPT_DIR/$src_path" "$dst_path" && ok "$label" || warn "$label (copy failed)"
    else
      warn "$label (not found)"
    fi
  else
    STATUS=$(curl -sL -w "%{http_code}" -o "$dst_path" "$REPO_RAW/$src_path")
    if [ "$STATUS" = "200" ]; then
      ok "$label"
    else
      warn "$label (HTTP $STATUS)"
      rm -f "$dst_path"
    fi
  fi
}

# ── Install commands (24) ────────────────────────────────────────────────────
echo ""
echo "  Installing 24 commands..."
for cmd in "${COMMANDS[@]}"; do
  install_file "commands/$cmd.md" "$COMMANDS_DIR/$cmd.md" "cmd: /$cmd"
done

# ── Install agents (13) ──────────────────────────────────────────────────────
echo ""
echo "  Installing 13 agents..."
for agent in "${AGENT_FILES[@]}"; do
  install_file "agents/$agent" "$AGENTS_DIR/$agent" "agent: $agent"
done

# ── Install skills (27) ──────────────────────────────────────────────────────
echo ""
echo "  Installing 27 skills..."
for skill in "${SKILLS[@]}"; do
  # Schemas end in .json, rest in .md
  if [[ "$skill" == *.schema ]]; then
    install_file "skills/${skill}.json" "$SKILLS_DIR/${skill}.json" "skill: $skill.json"
  elif [[ "$skill" == *state-structure ]]; then
    install_file "skills/${skill}.md" "$SKILLS_DIR/${skill}.md" "skill: $skill.md"
  else
    install_file "skills/${skill}.md" "$SKILLS_DIR/${skill}.md" "skill: $skill.md"
  fi
done

# ── Create .env.example if missing ───────────────────────────────────────────
echo ""
if [ ! -f "$TARGET/.env.example" ]; then
  cat > "$TARGET/.env.example" <<'EOF'
# ──────────────────────────────────────────────────────────────────
# Marketing Agents v2.0 — Environment variables
# Copy to .env and fill in your values. Run /briefing new for setup.
# ──────────────────────────────────────────────────────────────────

# --- ANTHROPIC (required) ---
ANTHROPIC_API_KEY=sk-ant-...

# --- TELEGRAM (required for approvals and notifications) ---
TELEGRAM_BOT_TOKEN=       # Get from @BotFather on Telegram
TELEGRAM_CHAT_ID=         # Chat ID where you'll approve/receive alerts

# --- META (Instagram + Facebook) ---
INSTAGRAM_ACCESS_TOKEN=
INSTAGRAM_BUSINESS_ACCOUNT_ID=
FACEBOOK_ACCESS_TOKEN=
FACEBOOK_PAGE_ID=
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=

# --- META ADS (required if paid-media budget > 0) ---
META_ADS_ACCESS_TOKEN=    # Can be same as FACEBOOK_ACCESS_TOKEN if business
META_ADS_ACCOUNT_ID=      # act_XXXXXXXXXX

# --- TIKTOK (optional) ---
TIKTOK_ACCESS_TOKEN=      # Expires every 24h
TIKTOK_OPEN_ID=

# --- TIKTOK ADS (optional, required for paid-media on TikTok) ---
TIKTOK_ADS_ACCESS_TOKEN=
TIKTOK_ADS_ADVERTISER_ID=

# --- AI IMAGE GENERATION (fal.ai recommended) ---
FAL_KEY=                  # ~$0.003/image — https://fal.ai

# Note: Client-specific business data (COMPANY_NAME, INDUSTRY, SENDER_NAME,
# ICP, KPIs, budget, buyer_persona) lives in .claude/client-brief.json
# — not in environment variables. Run /briefing new to populate it.
EOF
  ok ".env.example created"
else
  warn ".env.example already exists, skipped"
fi

# ── Add to .gitignore ────────────────────────────────────────────────────────
GITIGNORE="$TARGET/.gitignore"
if ! grep -q "Marketing Agents" "$GITIGNORE" 2>/dev/null; then
  cat >> "$GITIGNORE" <<'EOF'

# Marketing Agents — local data
.env
.claude/client-brief.json
.claude/brand-kit.json
.claude/brand-images/
.claude/state/
EOF
  ok ".gitignore updated"
else
  warn ".gitignore already configured"
fi

# ── Create minimal CLAUDE.md if missing ──────────────────────────────────────
if [ ! -f "$TARGET/CLAUDE.md" ]; then
  cat > "$TARGET/CLAUDE.md" <<EOF
# $(basename "$TARGET") — Marketing Agents Toolkit

This project uses the Marketing Agents v2.0 toolkit for Claude Code.

## Quick start

1. Copy \`.env.example\` to \`.env\` and fill credentials
2. Run \`/briefing new\` — create client brief (10-15 min)
3. Run \`/setup-check\` — validate credentials
4. Run \`/audit\` — audit current social accounts (optional but recommended)
5. Run \`/brand-kit new\` — extract brand identity
6. Run \`/content-calendar\` — generate monthly content plan
7. Run \`/publish-today\` to start operating daily

## Full 6-phase workflow

| Phase | Command | Agent |
|---|---|---|
| 1. Diagnosis | /briefing, /audit | account-auditor |
| 2. Brand | /brand-kit, /optimize-profiles | brand-guardian |
| 3. Planning | /content-calendar | content-planner |
| 4. Production | /production-plan | producer |
| 5. Publishing | /publish-today | content-publisher |
| 5. Community | /community | community-manager |
| 5. Ads | /ads | paid-media |
| 6. Monitoring | /social-report | social-monitor |
| 6. Optimization | /report-monthly, /dashboard | performance-analyst |

For automation: run \`/daily\` via Railway cron.
EOF
  ok "CLAUDE.md created"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}✓ Toolkit installed in $CLAUDE_DIR${RESET}"
echo ""
echo "  Next steps:"
echo "    1. Open Claude Code in this directory"
echo "    2. Copy .env.example → .env and fill credentials"
echo "    3. Run ${CYAN}/briefing new${RESET} to onboard your client"
echo "    4. Run ${CYAN}/setup-check${RESET} to validate everything"
echo "    5. (optional) ${CYAN}/audit${RESET} to baseline current accounts"
echo ""
echo "  Full workflow guide: $CLAUDE_DIR/skills/_core/schemas/state-structure.md"
echo ""
