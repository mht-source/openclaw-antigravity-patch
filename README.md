# openclaw-antigravity-patch

Patch enabling full Gemini 3.1 / Claude 4.6 / GPT-OSS model access via Google Antigravity in [OpenClaw](https://github.com/openclaw/openclaw).

Tested on **OpenClaw 2026.2.19-2** / Arch Linux.

---

## What this fixes

| Problem | Symptom | Fix |
|---------|---------|-----|
| Wrong API endpoint | Models return errors or use sandbox | `cloudcode-pa.sandbox` → `daily-cloudcode-pa` |
| Old client version | `"Gemini 3.1 is not available on this version"` | Version `1.15.8` → `1.18.3` |
| Missing models | `Error: Unknown model: google-antigravity/gemini-3.1-pro-high` | Added to `models.generated.js` |
| Broken tool schema | `400: Unknown name "patternProperties"` | Fixed `isAnthropicProvider` logic |
| Model not in allowlist | `model not allowed: google-antigravity/...` | Added models to `openclaw.json` |

## Quick start

```bash
git clone https://github.com/mht-source/openclaw-antigravity-patch
cd openclaw-antigravity-patch
bash patch.sh
```

Restart OpenClaw. Done.

## After OpenClaw update

```bash
bash patch.sh
```

The script is idempotent — safe to run multiple times.

## Repo structure

```
├── patch.sh          # Main patch script
├── README.md
├── PATCH.md          # Detailed technical documentation
└── config/
    ├── openclaw.json # Reference config (no tokens — copy and adapt)
    └── models.json   # ~/.openclaw/agents/main/agent/models.json
```

## Available models (Feb 2026)

After patching, all of these work via `google-antigravity`:

- `gemini-3.1-pro-high` — best quality
- `gemini-3.1-pro-low`
- `gemini-3-pro-high`
- `gemini-3-flash`
- `gemini-2.5-pro`
- `gemini-2.5-flash`
- `gemini-2.5-flash-lite`
- `gemini-2.5-flash-thinking`
- `claude-opus-4-6-thinking`
- `claude-sonnet-4-6`
- `gpt-oss-120b-medium` (OpenAI on Google Vertex)

## Platform

Default platform string is `linux/amd64`. Edit `patch.sh` line 13 for macOS:

```bash
PLATFORM="darwin/arm64"
```

## See also

Full technical writeup: [OPENCLAW_ANTIGRAVITY_PATCH.md](OPENCLAW_ANTIGRAVITY_PATCH.md)
