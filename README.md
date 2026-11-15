# ReactWheel

[![Latest release](https://img.shields.io/github/v/release/coffeemkr0/ReactWheel?label=latest%20release&sort=semver&cacheSeconds=300)](https://github.com/coffeemkr0/ReactWheel/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/coffeemkr0/ReactWheel/total?label=downloads&cacheSeconds=300)](https://github.com/coffeemkr0/ReactWheel/releases)
[![Tests](https://github.com/coffeemkr0/ReactWheel/actions/workflows/ci.yml/badge.svg)](https://github.com/coffeemkr0/ReactWheel/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

| | |
|---|---|
| **Download** | [**Latest release**](https://github.com/coffeemkr0/ReactWheel/releases/latest) &middot; [All releases](https://github.com/coffeemkr0/ReactWheel/releases) |
| **What changed** | [Changelog](CHANGELOG.md) &middot; [Release notes](https://github.com/coffeemkr0/ReactWheel/releases) |
| **Need help?** | [User guide below](#quick-start) &middot; [Troubleshooting](#troubleshooting) &middot; [Report a problem](https://github.com/coffeemkr0/ReactWheel/issues) |

> **New in 1.0.3:** replying to **Battle.net friend** whispers now works. (1.0.2: the wheel remembers the one you picked, and the **Key bindings...** button and Targeting tab layout were fixed.) See the [changelog](CHANGELOG.md).

**Reply to chat with one click.** Press a key, a wheel of quick reactions appears at your cursor, click one — and it goes to the right place (the person who whispered you, your party, your raid, your guild or `/say`) along with a matching emote. Think of the reactions in Microsoft Teams, for WoW.

- A wheel of 4–12 reactions, as many wheels as you like (Quick Chat, Dungeon / Raid, Social / Guild and Emotes come ready-made)
- **Smart replies:** it works out where your reaction should go, and asks you if it can't tell
- Thumbs up/down, hearts, "thanks!", "omw" — or anything you want, including slash commands
- Change anything from the settings window, or right-click a slice to edit it on the spot
- Works in combat; share your wheels with friends as a line of text

---

## Contents
1. [Install](#install)
2. [Quick start](#quick-start)
3. [Using the wheel](#using-the-wheel)
4. [Where do my reactions go?](#where-do-my-reactions-go)
5. [Customizing](#customizing)
6. [Settings window](#settings-window)
7. [Sharing wheels](#sharing-wheels)
8. [About /say](#about-say)
9. [Emotes](#emotes)
10. [Commands](#commands)
11. [Troubleshooting](#troubleshooting)
12. [For developers](#for-developers)

---

## Install
1. Download the latest **ReactWheel-x.y.z.zip** from the [latest release](https://github.com/coffeemkr0/ReactWheel/releases/latest) and unzip it. (Or clone this repository.)
2. Copy the whole **`ReactWheel`** folder into your game's `Interface/AddOns/` folder (the folder name must be exactly `ReactWheel`, with `ReactWheel.toc` directly inside it).
3. Start the game. New files such as images only load on a full restart, so don't rely on `/reload` for a first install or an update that adds files.

## Quick start
1. **Pick a key.** Press `Esc` → **Key Bindings** → **AddOns** → **ReactWheel**, and set **Reaction wheel (open / hold)**. (Shortcut: Settings > Display > **Key bindings...**, or the **Set key...** button in the welcome window that appears the first time you log in with no key set.)
2. **Press your key.** The wheel opens around your mouse.
3. **Click a reaction.** It's sent and the wheel closes.

That's all you need. Everything else below is optional.

## Using the wheel
| You want to… | Do this |
|---|---|
| Open the wheel | Press your key (it opens at the cursor; you can change it to the screen centre) |
| Send a reaction | **Left-click** a slice |
| Close without sending | Press `Esc`, press your key again, click outside the wheel, or click the **x** in the middle |
| Switch to another wheel | **Scroll the mouse wheel**, or click the **<** and **>** arrows in the middle (the middle shows "1/4" etc.) |
| Edit or move a reaction | **Right-click** the slice for a small menu: **Slot settings...** (edit it) or **Swap with another slot...** (then click the slice to swap with; click the same slice or right-click to cancel) |
| Open a sub-wheel | Slices set up as "opens another wheel" do so on click; the **<** button in the middle goes back |

Tips:
- The whole slice area is clickable, not just the round button.
- The centre of the wheel shows where your reaction will go and the name of the slice under your cursor.
- In **Hold** mode (Settings → Display → Opening) the wheel only shows while the key is held. Click a slice while still holding it.
- Reactions sent within half a second of each other are ignored, so a double-click can't send twice. Change this in Settings → Display ("Pause between reactions").

## Where do my reactions go?
By default every reaction uses **smart reply**. It picks the first of these that applies:

1. **A whisper from the last 30 seconds** → replies to that person (including Battle.net friends)
2. **Guild chat from the last 20 seconds** → guild
3. **You're in a group** → raid chat if you're in a raid, otherwise party
4. **Someone spoke in `/say` recently** → say
5. **Otherwise** → say

The centre of the wheel always shows the result, for example `-> Whisper Bob (12s)`. A green line means it's confident, an orange one means it isn't.

**If it can't tell** (for example, guild and party are both chatting, or the last whisper is old), it doesn't guess: after you click a reaction a small box asks where to send it, with the best guess highlighted.

**You are always in control:**
- **Click the destination in the centre** before choosing a reaction, to switch to the next option.
- **Shift+click** a reaction to send it to the next-best destination.
- **Ctrl+click** a reaction to always get the "send to…" box.
- **Fixed destinations:** any slice (or whole wheel) can be set to always go to Say, Party, Raid, Guild, or whisper your current target. If that isn't available (say, Party while solo), smart reply is used instead.

Numbered chat channels (General, Trade…) are never used, on purpose.

All of the timings and the order of the checks can be changed in **Settings → Targeting**, including a line that shows where a reaction would go right now and why.

## Customizing
### Edit a single reaction
**Right-click a slice** and choose **Slot settings...** (or just click an empty `+` slice). You can set:

- **Label** – the text on the wheel
- **Chat text** – what is sent. Tokens: `%t` = your target's name, `%p` = your name, `%z` = your zone
- **Emote** – e.g. `WAVE`, `CHEER`, `THANK` (use the `...` button to step through common ones)
- **Play emote when** – only where people can see it (default), always, or never
- **Slash command** – run something like `/dance` or `/roll` instead of sending text
- **Send to** – the wheel's default, smart reply, Say, Party, Raid, Guild, or whisper your target
- **Icon** – a game icon name such as `INV_Misc_Note_01`, or leave it empty to show the label as text
- **Colour** – white, green, red, pink, blue or gold
- **Opens another wheel** – turns the slice into a button that opens a sub-wheel

Use **Test** to try it out, **Clear** to empty the slice, **Save** when you're done.

### The ready-made wheels
| Wheel | What's on it |
|---|---|
| **Quick Chat** | 👍 and 👎 icons (send `√` and `▼`), `♥`, LOL, GG, thanks!, omw, what? |
| **Dungeon / Raid** | ready, wait, pull!, rez?, oom, heal?, sorry, nice |
| **Social / Guild** | grats!, hi, bye, nice, lol, thanks!, my bad, `♥` |
| **Emotes** | dance, wave, cheer, bow, salute, flex, cry, laugh (emote only, no chat text) |

Anything you edit is saved automatically. Use **Settings → Display → Reset everything** to go back to these.

## Settings window
Open it with `/rw config`, a click on the **minimap button**, or the "open settings" key binding.

| Tab | What it does |
|---|---|
| **Wheels** | Pick a wheel; add, copy, delete, rename and reorder wheels; set 4–12 slots; set a wheel's default destination; choose when it opens automatically; click any slot to edit it |
| **Display** | Button size, text size, centre-control size, ring radius, overall scale, pause between reactions; press-to-open or hold-to-show; open at cursor or screen centre; minimap button on/off; shared wheels vs. this character only; automatic wheel switching; sounds; **Reset wheels** and **Reset everything** |
| **Targeting** | How long a whisper / guild / group / say message counts as "recent"; reorder or switch off the smart-reply checks; what to do when unsure; keep replying to the last whisperer; ignore whispers from certain people; `/say` sending |
| **Emotes** | Whether emotes also play for whispers and for guild chat |
| **Share** | Export and import wheels |

**Minimap button:** left-click = settings, right-click = pick a wheel to open, drag = move it.

**Make the wheel bigger:** if buttons or text are too small, raise *Button size*, *Text size* and *Centre controls* on the Display tab (or use `/rw size`). The ring grows to fit.

**Switch wheel when my situation changes** (Display, off by default): when you get a whisper, join a group or go solo, the next time you open the wheel it switches to Quick Chat, Dungeon / Raid or Social / Guild respectively. Otherwise it reopens the wheel you used last, so a wheel you picked yourself stays put. Change which wheel goes with which situation on the Wheels tab ("Auto-opens").

**Shared or per-character:** wheels are shared by all your characters by default. Switch a character to its own copy under Display → "Wheels are".

**Sounds:** an optional soft tick when you move between slices and a click when a reaction is sent (Display → Play sounds).

Settings and editing are locked during combat (the wheel itself still opens and sends).

## Sharing wheels
**Settings → Share**:
- **Export this wheel** or **Export all wheels** puts a line of text starting with `RW1:` in the box. Press `Ctrl+C` to copy it and send it to a friend.
- To import, paste the text into the box and click **Import**. The wheels are added alongside yours; nothing is overwritten.
- If an imported wheel contains slash commands, you're shown them first and must click Import a second time to accept. Imported text is checked and cleaned, and links to other wheels are removed.

## About /say
The game restricts addons from sending `/say` and `/yell` outdoors unless the message comes from your own keypress. Whispers, party, raid and guild are not restricted.

Whether a given wheel click counts is up to the game, so ReactWheel **tries to send `/say` every time**. When the game refuses, it quietly types the line into your chat box instead (no error popup), and you just press `Enter`. You'll see a one-time note explaining this.

If you'd rather always use the chat box for `/say`, set Settings → Targeting → "/say sending" to *Always chat box* (or `/rw say prefill`).

## Emotes
Most reactions play a matching emote (nod, laugh, clap, thank…). Emotes can only be seen by people near you, so by default they only play when the reaction goes to **say, party or raid** — not for whispers or guild chat. You can switch that on in Settings → Emotes, or set it per reaction in the editor.

## Commands
| Command | What it does |
|---|---|
| `/rw` or `/rw config` | Open the settings window |
| `/rw wheel <name or number>` | Open a specific wheel |
| `/rw profile <account\|char>` | Use shared wheels or this character's own |
| `/rw size buttons <40-110>` / `font <0.7-2.5>` / `hub <0.8-2.5>` | Resize the wheel |
| `/rw say <auto\|prefill>` | How `/say` is sent (see above) |
| `/rw debug` | Print where a reaction would go right now and why |
| `/rw reset all` | Reset every wheel and setting to the defaults |

`/reactwheel` works the same as `/rw`.

## Troubleshooting
| Problem | Try this |
|---|---|
| Nothing happens when I press my key | Check Key Bindings → ReactWheel; make sure no other addon uses the same key |
| Slices are blank squares or the thumbs are missing | The images only load on a full game restart; restart rather than `/reload` |
| `/say` reaction needs me to press Enter | That's the game's rule for outdoor `/say` — see [About /say](#about-say) |
| The reaction went to the wrong place | Check the destination shown in the centre before clicking; click it to change; or set a fixed destination for that slice |
| I get asked "Send to:" after clicking | The addon wasn't sure where it should go. Pick one, or turn that off under Targeting → "When unsure" |
| I can't edit in combat | Editing and the settings window are locked during combat by design |
| I changed things and want to start over | Settings → Display → **Reset everything** (or `/rw reset all`) |
| Something looks wrong | Run `/rw debug`, and open an issue with what it prints |

## For developers
**Release:** `scripts/package.sh` builds `dist/ReactWheel-<version>.zip` (addon files only). Pushing a tag like `v1.0.0` runs the tests and publishes that zip as a GitHub release automatically; every push also runs the tests (`.github/workflows`).

Source layout:

| File | Purpose |
|---|---|
| `Core.lua` | Saved data, profiles, chat tracking, slash commands |
| `Defaults.lua` | Default settings and the starter wheels |
| `Targeting.lua` | The smart-reply engine |
| `Actions.lua` | What happens when a slot is used (send, emote, command, `/say` handling) |
| `Wheel.lua` | The radial menu |
| `Editor.lua` / `Config.lua` / `Share.lua` / `Minimap.lua` | Slot editor, settings window, import/export, minimap button |
| `Bindings.xml` | Key bindings (loaded automatically; not listed in the `.toc`) |
| `tests/` | Logic tests |

Run the tests (they load the addon files against stubbed game functions under Lua 5.1):

```bash
pip install lupa
python tests/run_tests.py
```

## License
MIT
