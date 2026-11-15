# Spy Tool

Developer tooling for inspecting remotes, modules, and HTTP traffic in experiences you own or have edit access to.

## Important — own games only

**Use this only on places/experiences you own or have edit permissions for.**

Roblox stated this policy in the Developer Forum announcement:

**[An Update on Automated Action Against Modified Clients](https://devforum.roblox.com/t/an-update-on-automated-action-against-modified-clients/3640609)**

In that thread, Roblox explained that creators with edit permissions may use a modified client **in that place only** (for example, to test anti-cheat). Using a modified client in someone else’s experience is subject to enforcement, up to account termination.

Do **not** use this project against games you do not own or are not authorized to develop.

## Layout / assets

Keep this project as a folder named `spyTool` in your executor workspace:

- `spyTool/spyTool.lua` — loader (run this)
- `spyTool/main.lua` — full tool (loaded via `readfile` + `loadstring`)
- `spyTool/asset/` — local icons via `getcustomasset` (letter fallback if unavailable)

Chrome uses sliced **Squircle** image plates as the entire frame (iOS G2 continuous corners). Local plates live in `spyTool/asset/squircle/` and load via `getcustomasset` (with `rbxassetid` fallback). Selective top/bottom plates (`squircle-tl-tr.png` / `squircle-bl-br.png`) replace `UICorner` cover hacks.

If your workspace root *is* the project folder, the loader also tries `main.lua`.

## Intended use

- Debugging networking in **your** place during Studio/playtesting
- Understanding remotes, module returns, and HTTP surfaces you control
- Building and verifying systems in experiences you have edit access to

## Not intended for

- Third-party games without authorization
- Circumventing Roblox security or moderation
- Cheating, griefing, or unauthorized access

## Disclaimer

This repository is provided for legitimate development and testing of your own work. You are responsible for complying with [Roblox Terms of Use](https://en.help.roblox.com/hc/en-us/articles/115004647846), Community Standards, and applicable law.
