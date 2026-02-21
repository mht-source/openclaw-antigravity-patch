# OpenClaw × Google Antigravity — Patch Documentation

> Enables full Gemini 3.1 / Claude 4.x / GPT-OSS model access via Google Antigravity IDE integration in OpenClaw.

---

## Background

OpenClaw supports Google Antigravity as an OAuth provider (`google-antigravity`), but ships with an outdated configuration that prevents newer models from working. This patch fixes three categories of issues:

1. **Wrong API endpoint** — OpenClaw uses the old `cloudcode-pa.googleapis.com` sandbox; the live endpoint is `daily-cloudcode-pa.googleapis.com`
2. **Missing models** — `models.generated.js` only includes older `4.5` Claude models; Gemini 3.1, Claude 4.6, and GPT-OSS are absent
3. **Broken schema cleaning** — `google-antigravity` is incorrectly classified as an Anthropic-style provider, causing `patternProperties` errors when sending tool schemas to Gemini models

---

## Discovered API Details

Endpoint discovered via network interception of real Antigravity IDE traffic:

| Property | Value |
|----------|-------|
| Endpoint | `https://daily-cloudcode-pa.googleapis.com` |
| Auth | OAuth2 Bearer token (Google account) |
| Stream path | `POST /v1internal:streamGenerateContent?alt=sse` |
| Models path | `POST /v1internal:fetchAvailableModels` |
| User-Agent | `antigravity/1.18.3 linux/amd64` |

### Available models (as of Feb 2026)

Retrieved via `/v1internal:fetchAvailableModels`:

| Model ID | Provider | Notes |
|----------|----------|-------|
| `gemini-3.1-pro-high` | Google | Primary target — best quality |
| `gemini-3.1-pro-low` | Google | Faster/cheaper variant |
| `gemini-3-pro-high` | Google | Previous generation |
| `gemini-3-flash` | Google | Fast, lightweight |
| `gemini-2.5-pro` | Google | Stable release |
| `gemini-2.5-flash` | Google | |
| `gemini-2.5-flash-lite` | Google | |
| `gemini-2.5-flash-thinking` | Google | |
| `claude-opus-4-6-thinking` | Anthropic | Via Antigravity proxy |
| `claude-sonnet-4-6` | Anthropic | |
| `claude-opus-4-5-thinking` | Anthropic | Previous gen (already in OpenClaw) |
| `claude-sonnet-4-5` | Anthropic | Previous gen (already in OpenClaw) |
| `gpt-oss-120b-medium` | OpenAI | Hosted on Google Vertex |

---

## Files Modified

### 1. `openclaw/node_modules/@mariozechner/pi-ai/dist/providers/google-gemini-cli.js`

**What:** Runtime configuration for the Antigravity API client.

**Changes:**
- `DEFAULT_ANTIGRAVITY_VERSION`: `"1.15.8"` → `"1.18.3"`
- `User-Agent` platform: `darwin/arm64` → `linux/amd64` (adjust for your OS)
- `ANTIGRAVITY_DAILY_ENDPOINT`: `https://daily-cloudcode-pa.sandbox.googleapis.com` → `https://daily-cloudcode-pa.googleapis.com`

**Why:** Antigravity API rejects requests from outdated client versions with `"Gemini 3.1 Pro is not available on this version. Please upgrade."` The sandbox endpoint no longer serves production models.

---

### 2. `openclaw/node_modules/@mariozechner/pi-ai/dist/models.generated.js`

**What:** Generated registry of all built-in models per provider.

**Changes:** Added the following models to the `"google-antigravity"` block, all using:
- `api: "google-gemini-cli"`
- `baseUrl: "https://daily-cloudcode-pa.googleapis.com"` (production, not sandbox)

New models added:
- `gemini-3.1-pro-high` — `contextWindow: 1000000`, `maxTokens: 65535`, `reasoning: true`
- `gemini-3.1-pro-low` — same specs
- `gemini-2.5-pro` — same specs
- `gemini-2.5-flash` — `cost: { input: 0.5, output: 3 }`
- `gemini-2.5-flash-lite` — `reasoning: false`, lower cost
- `gemini-2.5-flash-thinking` — `reasoning: true`
- `claude-opus-4-6-thinking` — `contextWindow: 200000`, `maxTokens: 64000`
- `claude-sonnet-4-6` — same specs, `reasoning: false`
- `gpt-oss-120b-medium` — `contextWindow: 114000`, `maxTokens: 32768`

Also updated all existing `google-antigravity` models to use the production endpoint (replacing `.sandbox.googleapis.com`).

**Why:** OpenClaw validates model IDs against this registry before sending requests. Unknown models throw `Error: Unknown model: google-antigravity/<id>`.

---

### 3. `openclaw/dist/pi-embedded-CHb5giY2.js` and `pi-embedded-Cn8f5u97.js`

**What:** Core embedded agent runtime.

**Changes:**
- All occurrences of `cloudcode-pa.googleapis.com` → `daily-cloudcode-pa.googleapis.com`
- `isAnthropicProvider` condition: removed `|| options?.modelProvider?.toLowerCase().includes("google-antigravity")`

**Why:** The `isAnthropicProvider` flag suppressed `cleanSchemaForGemini()` for all Antigravity models, including Gemini ones. Gemini models require JSON Schema cleaning (removing `patternProperties`, `$ref`, etc.) before the schema is sent as tool declarations. Without this fix, all tool calls fail with `Cloud Code Assist API error (400): Invalid JSON payload received. Unknown name "patternProperties"`.

Note: Claude models through Antigravity still work correctly because they use `parameters` (legacy field) instead of the cleaned Gemini schema — this is handled separately via `model.id.startsWith("claude-")` check which remains untouched.

---

### 4. `openclaw/dist/reply-B4B0jUCM.js`, `plugin-sdk/reply-Bsg9j6AP.js`, `subagent-registry-DOZpiiys.js`

**What:** Reply handlers and subagent registry.

**Changes:** Same as above — endpoint replacement and `isAnthropicProvider` fix.

---

## User Configuration (`~/.openclaw/`)

### `openclaw.json`

Models must be explicitly listed in `agents.defaults.models` or OpenClaw will reject them with `model not allowed`. Add all desired models:

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "google-antigravity/gemini-3.1-pro-high",
        "fallbacks": ["openai-codex/gpt-5.3-codex"]
      },
      "models": {
        "google-antigravity/gemini-3.1-pro-high": {},
        "google-antigravity/gemini-3.1-pro-low": {},
        "google-antigravity/gemini-3-pro-high": {},
        "google-antigravity/gemini-3-flash": {},
        "google-antigravity/gemini-2.5-pro": {},
        "google-antigravity/gemini-2.5-flash": {},
        "google-antigravity/gemini-2.5-flash-lite": {},
        "google-antigravity/gemini-2.5-flash-thinking": {},
        "google-antigravity/claude-opus-4-6-thinking": {},
        "google-antigravity/claude-sonnet-4-6": {},
        "google-antigravity/gpt-oss-120b-medium": {},
        "openai-codex/gpt-5.3-codex": {}
      }
    }
  }
}
```

### `agents/main/agent/models.json`

Created manually (OpenClaw does not auto-generate this file). Used to register model overrides without modifying npm packages. Minimal content:

```json
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
```

> **Note:** `modelOverrides` alone does not register new models — it only overrides existing ones. New models must be added to `models.generated.js`. This file is still useful as a fallback/reference.

---

## How Model Routing Works (OpenClaw internals)

```
openclaw.json (primary model)
    ↓
model-selection-ynGV0Z-S.js :: resolveAllowedModelRef()
    ↓ checks agents.defaults.models allowlist
    ↓ throws "model not allowed" if missing
    ↓
pi-model-discovery-DaNAekda.js :: ModelRegistry
    ↓ loads from @mariozechner/pi-coding-agent ModelRegistry
    ↓ reads models.generated.js (built-ins) + models.json (custom)
    ↓ throws "Unknown model" if not in registry
    ↓
pi-embedded-CHb5giY2.js :: normalizeToolParameters()
    ↓ isGeminiProvider = provider includes "google"
    ↓ isAnthropicProvider = provider includes "anthropic" (PATCHED: removed google-antigravity)
    ↓ cleanSchemaForGemini() called for Gemini models
    ↓
@mariozechner/pi-ai :: google-gemini-cli provider
    ↓ adds auth headers, User-Agent, project ID
    ↓ POST daily-cloudcode-pa.googleapis.com/v1internal:streamGenerateContent?alt=sse
```

---

## Notes & Caveats

- **Token lifetime:** Google OAuth tokens expire after ~1 hour. OpenClaw refreshes them automatically via the stored `refresh` token in `auth-profiles.json`. No manual intervention needed.
- **Platform string:** `User-Agent` includes the platform (`linux/amd64`). Adjust to `darwin/arm64` on macOS or `windows/amd64` on Windows.
- **Cost data:** Costs in `models.generated.js` are estimates based on comparable public Gemini/Claude pricing. Actual billing goes through your Google Cloud project.
- **Model availability:** The list of available models depends on your Google account plan (free tier vs. paid). Query `/v1internal:fetchAvailableModels` with a valid token to see what your account can access.
- **Sandbox endpoint:** The `.sandbox.googleapis.com` endpoint appears to be a staging/preview environment with a restricted model set. Production models require the non-sandbox endpoint.
- **Patch fragility:** These are patches to minified dist files. An `npm update -g openclaw` will overwrite them. See the companion `patch.sh` script to reapply automatically.

---

## How to Verify

After applying the patch, verify the model is actually being used (not just claimed by the model itself):

```bash
# Check session logs — "model" field shows what OpenClaw actually sent
grep '"model"' ~/.openclaw/agents/main/sessions/*.jsonl | tail -5
```

The model field in session logs reflects what was sent to the API, regardless of what the model says about itself in its response.
