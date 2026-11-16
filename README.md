# Spy Tool

Developer tooling for inspecting remotes, modules, and HTTP traffic in experiences you own or have edit access to.

## Important — own games only

**Use this only on places/experiences you own or have edit permissions for.**

Roblox stated this policy in the Developer Forum announcement:

**[An Update on Automated Action Against Modified Clients](https://devforum.roblox.com/t/an-update-on-automated-action-against-modified-clients/3640609)**

In that thread, Roblox explained that creators with edit permissions may use a modified client **in that place only** (for example, to test anti-cheat). Using a modified client in someone else’s experience is subject to enforcement, up to account termination.

Do **not** use this project against games you do not own or are not authorized to develop.

## Run (recommended)

Always fetch the bootstrap from GitHub. It syncs your executor workspace differentially, then starts the tool:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ProBaconHub/spyTool/refs/heads/main/spyTool.lua?t=" .. tostring(tick()), true))()
```

What happens:

1. Downloads fresh `spyTool.lua` (this bootstrap)
2. Fetches remote `manifest.json` (file list + content hashes)
3. Creates `spyTool/` in the executor workspace if missing
4. Downloads **only** missing or changed files (modules, assets, `main.lua`, …)
5. `readfile`s local `spyTool/main.lua`, which concatenates `modules/*` and runs the app

Offline / already installed: if sync fails but `spyTool/main.lua` exists locally, the bootstrap still boots from disk.

## Layout

```text
spyTool/
  spyTool.lua              — GitHub bootstrap + differential sync
  main.lua                 — concatenates modules/* and executes
  manifest.json            — per-file hashes for partial updates
  modules/                 — app source (synced to workspace)
  asset/                   — icons + squircle plates (synced)
  installer/               — first-run UI only (GitHub → memory, NOT synced)
    ui.lua
    asset/spinner.png
  tools/                   — publisher scripts (not synced)
    split_and_manifest.ps1
```

On first install (no local `spyTool/main.lua`), the bootstrap HttpGets `installer/ui.lua` + spinner into memory, shows a usage-agreement screen (scrollable terms + acknowledge checkbox). Install is disabled until the box is checked. After confirmation it shows **Installing files** with a spinner/progress bar, then destroys the UI and cleans any temp spinner cache outside `spyTool/`. Cancel aborts with no files written.

Chrome uses sliced **Squircle** image plates as the entire frame (iOS G2 continuous corners). Local plates live in `spyTool/asset/squircle/` and load via `getcustomasset` (with `rbxassetid` fallback).

Settings stay outside the sync tree at `ProBaconHub/RemoteSpySettings.json`.

## Publishing updates

After changing source files:

```powershell
powershell -ExecutionPolicy Bypass -File tools/split_and_manifest.ps1
```

That refreshes `manifest.json` hashes (`adler32pair-length`). Commit and push to `main`. Clients pick up only the files whose hashes changed on next bootstrap run.

If you ever restore a single monolithic `main.lua`, the same script can re-split it into `modules/` (it detects the monolith automatically).

## Intended use

- Debugging networking in **your** place during Studio/playtesting
- Understanding remotes, module returns, and HTTP surfaces you control
- Building and verifying systems in experiences you have edit access to

## Not intended for

- Third-party games without authorization
- Circumventing Roblox security or moderation
- Cheating, griefing, or unauthorized access

## Disclaimer

This repository is provided for legitimate development and testing of your own work. You are responsible for complying with [Roblox Terms of Use](https://help.roblox.com/hc/en-us/articles/115004647846), Community Standards, and applicable law.
