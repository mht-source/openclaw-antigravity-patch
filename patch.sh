#!/usr/bin/env bash
# =============================================================================
# OpenClaw × Google Antigravity — Patch Script
# Tested on OpenClaw 2026.2.19-2 / Arch Linux
#
# Run after every `npm update -g openclaw` to reapply all fixes.
# Usage: bash patch.sh [--dry-run]
# =============================================================================

set -euo pipefail

# Detect OpenClaw installation directory
if [[ -d "$HOME/apps/openclaw" ]]; then
    OPENCLAW_DIR="$HOME/apps/openclaw"
elif command -v pnpm &>/dev/null && pnpm root -g &>/dev/null 2>&1; then
    OPENCLAW_DIR="$(pnpm root -g)/openclaw"
elif command -v npm &>/dev/null; then
    OPENCLAW_DIR="$(npm root -g)/openclaw"
else
    echo -e "\033[0;31m[✗]\033[0m Cannot find OpenClaw installation"
    exit 1
fi

# Detect pi-ai location — pnpm uses flat .pnpm structure with version hashes
PI_AI_DIR=$(find "$OPENCLAW_DIR/node_modules" -name "google-gemini-cli.js" -path "*/providers/*" 2>/dev/null | head -1 | sed 's|/dist/providers/google-gemini-cli.js||')
if [[ -z "$PI_AI_DIR" ]]; then
    echo -e "\033[0;31m[✗]\033[0m Cannot find @mariozechner/pi-ai in $OPENCLAW_DIR"
    exit 1
fi
DIST="$OPENCLAW_DIR/dist"
ANTIGRAVITY_VERSION="1.18.3"
PLATFORM="linux/amd64"  # change to darwin/arm64 on macOS

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
fail() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

patch_file() {
    local file="$1" from="$2" to="$3" desc="$4"
    if ! grep -qF "$from" "$file"; then
        if grep -qF "$to" "$file"; then
            warn "$desc — already patched, skipping"
        else
            warn "$desc — pattern not found in $(basename $file), may need manual update"
        fi
        return
    fi
    if $DRY_RUN; then
        log "[DRY RUN] Would patch: $desc"
        return
    fi
    cp "$file" "$file.prepatch.bak"
    python3 -c "
import sys
with open('$file', 'r') as f:
    content = f.read()
patched = content.replace($(printf '%s' "$from" | python3 -c "import sys; print(repr(sys.stdin.read()))"), $(printf '%s' "$to" | python3 -c "import sys; print(repr(sys.stdin.read()))"))
if patched == content:
    sys.exit(1)
with open('$file', 'w') as f:
    f.write(patched)
"
    log "$desc"
}

# =============================================================================
echo ""
echo "OpenClaw Antigravity Patch"
echo "OpenClaw dir: $OPENCLAW_DIR"
echo "pi-ai dir:    $PI_AI_DIR"
$DRY_RUN && echo -e "${YELLOW}DRY RUN MODE — no files will be modified${NC}"
echo ""

# =============================================================================
# 1. google-gemini-cli.js — version, platform, endpoint
# =============================================================================
GEMINI_CLI="$PI_AI_DIR/dist/providers/google-gemini-cli.js"
[[ -f "$GEMINI_CLI" ]] || fail "Not found: $GEMINI_CLI"

patch_file "$GEMINI_CLI" \
    'const DEFAULT_ANTIGRAVITY_VERSION = "1.15.8"' \
    "const DEFAULT_ANTIGRAVITY_VERSION = \"$ANTIGRAVITY_VERSION\"" \
    "google-gemini-cli: version 1.15.8 → $ANTIGRAVITY_VERSION"

patch_file "$GEMINI_CLI" \
    'antigravity/${version} darwin/arm64' \
    "antigravity/\${version} $PLATFORM" \
    "google-gemini-cli: platform darwin/arm64 → $PLATFORM"

patch_file "$GEMINI_CLI" \
    'daily-cloudcode-pa.sandbox.googleapis.com' \
    'daily-cloudcode-pa.googleapis.com' \
    "google-gemini-cli: sandbox endpoint → production"

# =============================================================================
# 2. models.generated.js — add new models
# =============================================================================
MODELS_JS="$PI_AI_DIR/dist/models.generated.js"
[[ -f "$MODELS_JS" ]] || fail "Not found: $MODELS_JS"

if grep -q '"gemini-3.1-pro-high"' "$MODELS_JS"; then
    warn "models.generated.js — new models already present, skipping"
else
    if $DRY_RUN; then
        log "[DRY RUN] Would add new models to models.generated.js"
    else
        cp "$MODELS_JS" "$MODELS_JS.prepatch.bak"
        MODELS_JS="$MODELS_JS" python3 << 'PYEOF'
import os
path = os.environ['MODELS_JS']

with open(path, 'r') as f:
    content = f.read()

new_models = '''        "gemini-3.1-pro-high": {
            id: "gemini-3.1-pro-high",
            name: "Gemini 3.1 Pro High (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25 },
            contextWindow: 1000000,
            maxTokens: 65535,
        },
        "gemini-3.1-pro-low": {
            id: "gemini-3.1-pro-low",
            name: "Gemini 3.1 Pro Low (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75 },
            contextWindow: 1000000,
            maxTokens: 65535,
        },
        "gemini-2.5-pro": {
            id: "gemini-2.5-pro",
            name: "Gemini 2.5 Pro (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75 },
            contextWindow: 1000000,
            maxTokens: 65535,
        },
        "gemini-2.5-flash": {
            id: "gemini-2.5-flash",
            name: "Gemini 2.5 Flash (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 0.5, output: 3, cacheRead: 0.5, cacheWrite: 0 },
            contextWindow: 1000000,
            maxTokens: 65535,
        },
        "gemini-2.5-flash-lite": {
            id: "gemini-2.5-flash-lite",
            name: "Gemini 2.5 Flash Lite (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: false,
            input: ["text", "image"],
            cost: { input: 0.1, output: 0.5, cacheRead: 0.1, cacheWrite: 0 },
            contextWindow: 1000000,
            maxTokens: 65535,
        },
        "gemini-2.5-flash-thinking": {
            id: "gemini-2.5-flash-thinking",
            name: "Gemini 2.5 Flash Thinking (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 0.5, output: 3, cacheRead: 0.5, cacheWrite: 0 },
            contextWindow: 1000000,
            maxTokens: 65535,
        },
        "claude-opus-4-6-thinking": {
            id: "claude-opus-4-6-thinking",
            name: "Claude Opus 4.6 Thinking (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 5, output: 25, cacheRead: 0.5, cacheWrite: 6.25 },
            contextWindow: 200000,
            maxTokens: 64000,
        },
        "claude-sonnet-4-6": {
            id: "claude-sonnet-4-6",
            name: "Claude Sonnet 4.6 (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: false,
            input: ["text", "image"],
            cost: { input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75 },
            contextWindow: 200000,
            maxTokens: 64000,
        },
        "gpt-oss-120b-medium": {
            id: "gpt-oss-120b-medium",
            name: "GPT-OSS 120B Medium (Antigravity)",
            api: "google-gemini-cli",
            provider: "google-antigravity",
            baseUrl: "https://daily-cloudcode-pa.googleapis.com",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 2, output: 8, cacheRead: 0.2, cacheWrite: 0 },
            contextWindow: 114000,
            maxTokens: 32768,
        },
'''

content = content.replace('"google-antigravity": {\n', '"google-antigravity": {\n' + new_models, 1)

# Also fix sandbox endpoint for existing models
content = content.replace('daily-cloudcode-pa.sandbox.googleapis.com', 'daily-cloudcode-pa.googleapis.com')

with open(path, 'w') as f:
    f.write(content)

print("OK")
PYEOF
        log "models.generated.js — added new models + fixed sandbox endpoint"
    fi
fi

# =============================================================================
# 3. dist files — endpoint + isAnthropicProvider fix
# =============================================================================

# Find all relevant dist files dynamically (hash in filename changes per version)
PI_EMBEDDED_FILES=$(find "$DIST" -maxdepth 1 -name "pi-embedded-*.js" ! -name "pi-embedded-helpers-*" ! -name "*.bak")
REPLY_FILES=$(find "$DIST" -maxdepth 1 -name "reply-*.js" ! -name "reply-prefix-*" ! -name "*.bak")
PLUGIN_REPLY=$(find "$DIST/plugin-sdk" -maxdepth 1 -name "reply-*.js" ! -name "reply-prefix-*" ! -name "*.bak" 2>/dev/null || true)
SUBAGENT=$(find "$DIST" -maxdepth 1 -name "subagent-registry-*.js" ! -name "*.bak")

ALL_DIST_FILES="$PI_EMBEDDED_FILES $REPLY_FILES $PLUGIN_REPLY $SUBAGENT"

for f in $ALL_DIST_FILES; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f")

    patch_file "$f" \
        'cloudcode-pa.googleapis.com' \
        'daily-cloudcode-pa.googleapis.com' \
        "$name: endpoint → daily-cloudcode-pa"

    patch_file "$f" \
        'options?.modelProvider?.toLowerCase().includes("google-antigravity")' \
        'false' \
        "$name: isAnthropicProvider — remove google-antigravity"
done

# =============================================================================
# 4. openclaw.json — ensure all models are in allowlist
# =============================================================================
OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"

if [[ -f "$OPENCLAW_JSON" ]]; then
    if $DRY_RUN; then
        log "[DRY RUN] Would update $OPENCLAW_JSON allowlist"
    else
        python3 << PYEOF
import json

path = "$OPENCLAW_JSON"
with open(path) as f:
    config = json.load(f)

models_to_add = [
    "google-antigravity/gemini-3.1-pro-high",
    "google-antigravity/gemini-3.1-pro-low",
    "google-antigravity/gemini-3-pro-high",
    "google-antigravity/gemini-3-flash",
    "google-antigravity/gemini-2.5-pro",
    "google-antigravity/gemini-2.5-flash",
    "google-antigravity/gemini-2.5-flash-lite",
    "google-antigravity/gemini-2.5-flash-thinking",
    "google-antigravity/claude-opus-4-6-thinking",
    "google-antigravity/claude-sonnet-4-6",
    "google-antigravity/gpt-oss-120b-medium",
]

existing = config.get("agents", {}).get("defaults", {}).get("models", {})
added = 0
for m in models_to_add:
    if m not in existing:
        existing[m] = {}
        added += 1

config.setdefault("agents", {}).setdefault("defaults", {})["models"] = existing

with open(path, "w") as f:
    json.dump(config, f, indent=2)

print(f"openclaw.json: added {added} missing models to allowlist")
PYEOF
        log "openclaw.json allowlist updated"
    fi
else
    warn "~/.openclaw/openclaw.json not found — skipping allowlist update"
fi

# =============================================================================
# 5. models.json — ensure file exists
# =============================================================================
MODELS_JSON="$HOME/.openclaw/agents/main/agent/models.json"

if [[ ! -f "$MODELS_JSON" ]]; then
    if $DRY_RUN; then
        log "[DRY RUN] Would create $MODELS_JSON"
    else
        mkdir -p "$(dirname "$MODELS_JSON")"
        cat > "$MODELS_JSON" << 'EOF'
{
  "providers": {
    "google-antigravity": {
      "modelOverrides": {
        "gemini-3.1-pro-high": {},
        "gemini-3.1-pro-low": {},
        "gemini-3-pro-high": {},
        "gemini-3-flash": {},
        "gemini-2.5-pro": {},
        "gemini-2.5-flash": {},
        "gemini-2.5-flash-lite": {},
        "gemini-2.5-flash-thinking": {},
        "claude-opus-4-6-thinking": {},
        "claude-sonnet-4-6": {},
        "gpt-oss-120b-medium": {}
      }
    }
  }
}
EOF
        log "models.json created"
    fi
else
    log "models.json already exists, skipping"
fi

# =============================================================================
echo ""
echo -e "${GREEN}Patch complete.${NC} Restart OpenClaw to apply changes."
echo ""
