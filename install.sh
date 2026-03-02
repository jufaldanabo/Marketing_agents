#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Marketing Agents Plugin — Installer
#
# Usage (from cloned repo):
#   bash install.sh
#   bash install.sh /path/to/target-project
#
# Usage (one-liner, no clone needed):
#   bash <(curl -sL https://raw.githubusercontent.com/TU_USUARIO/Marketing_agents/main/install.sh)
# ─────────────────────────────────────────────────────────────────────────────
set -e

REPO_RAW="https://raw.githubusercontent.com/TU_USUARIO/Marketing_agents/main"
TARGET="${1:-$(pwd)}"
COMMANDS_DIR="$TARGET/.claude/commands"

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RESET="\033[0m"
ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}·${RESET} $1"; }

COMMANDS=(
  init setup-check publish-today social-report market-intel
  prospect-leads respond-comments followup-leads
  check-approvals setup-railway security-audit
)

echo ""
echo "  Marketing Agents — Installing plugin"
echo "  Target: $TARGET"
echo ""

# ── Create .claude/commands/ ─────────────────────────────────────────────────
mkdir -p "$COMMANDS_DIR"

# ── Detect local vs remote mode ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

if [ -d "$SCRIPT_DIR/commands" ] && ls "$SCRIPT_DIR/commands"/*.md &>/dev/null 2>&1; then
  # Local: copy from cloned repo
  for cmd in "${COMMANDS[@]}"; do
    [ -f "$SCRIPT_DIR/commands/$cmd.md" ] && \
      cp "$SCRIPT_DIR/commands/$cmd.md" "$COMMANDS_DIR/" && ok "$cmd" || \
      warn "$cmd (not found, skipped)"
  done
else
  # Remote: download from GitHub
  command -v curl &>/dev/null || { echo "curl is required"; exit 1; }
  for cmd in "${COMMANDS[@]}"; do
    STATUS=$(curl -sL -w "%{http_code}" -o "$COMMANDS_DIR/$cmd.md" "$REPO_RAW/commands/$cmd.md")
    [ "$STATUS" = "200" ] && ok "$cmd" || { warn "$cmd (HTTP $STATUS, skipped)"; rm -f "$COMMANDS_DIR/$cmd.md"; }
  done
fi

# ── Create .env.example if missing ───────────────────────────────────────────
if [ ! -f "$TARGET/.env.example" ]; then
  cat > "$TARGET/.env.example" <<'EOF'
# Marketing Agents Plugin — Environment variables
# Copy to .env and fill in your values. Run /init for guided setup.

ANTHROPIC_API_KEY=sk-ant-...

TELEGRAM_BOT_TOKEN=       # Get from @BotFather on Telegram
TELEGRAM_CHAT_ID=         # Your chat ID (see /init for instructions)

COMPANY_NAME=
INDUSTRY=
SENDER_NAME=
SENDER_ROLE=

# Meta — Instagram + Facebook
INSTAGRAM_ACCESS_TOKEN=
INSTAGRAM_BUSINESS_ACCOUNT_ID=
FACEBOOK_ACCESS_TOKEN=
FACEBOOK_PAGE_ID=
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=

# TikTok (optional)
TIKTOK_ACCESS_TOKEN=
TIKTOK_OPEN_ID=
EOF
  ok ".env.example created"
else
  warn ".env.example already exists, skipped"
fi

# ── Add .claude/ data dirs to .gitignore ─────────────────────────────────────
GITIGNORE="$TARGET/.gitignore"
if ! grep -q "\.claude/posts/" "$GITIGNORE" 2>/dev/null; then
  printf "\n# Marketing Agents — local data\n.env\n.claude/posts/\n.claude/reports/\n.claude/leads/\n.claude/intel/\n.claude/responses/\n.claude/drafts/\n.claude/runs/\n" >> "$GITIGNORE"
  ok ".gitignore updated"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}Plugin installed.${RESET} Commands available in .claude/commands/"
echo ""
echo "  Next steps:"
echo "    1. Open Claude Code in this directory"
echo "    2. Run /init  →  configure your company"
echo "    3. Run /setup-check  →  validate credentials"
echo ""
