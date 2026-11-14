# ReactWheel

A radial quick-reaction menu for WoW chat, inspired by Teams reactions. Open the wheel, click a reaction —
it is sent to the right place (whisper, party, raid, guild or say) and plays a matching emote.

## Install
Copy the `ReactWheel` folder into `Interface/AddOns/` and restart the game.

## Use
1. Esc > Key Bindings > ReactWheel: bind **Reaction wheel (open / hold)** (optionally also next/previous wheel and settings).
2. Press the key: the wheel opens at your cursor. **Left-click** a slice to send it. **Right-click** a slice to customize it.
3. Close without sending: **Esc**, press the key again, click outside the wheel, or use the **x** in the centre.
4. Scroll the mouse wheel (or use the arrows in the centre) to switch between wheels.

Starter wheels: **Quick Chat**, **Dungeon / Raid**, **Social / Guild**, **Emotes**.

## Customizing
- **Minimap button:** left-click opens the settings window, right-click lists your wheels, drag to move it.
- **Settings window** (`/rw config`): Wheels (add, copy, delete, reorder, rename, 4-12 slots, edit any slot), Display (sizes, open mode, per-character wheels), Targeting (smart reply rules and timings), Emotes, Share (export / import wheels as text).
- **Right-click a slice** to edit that slot: label, text, emote, slash command, destination, icon, colour, or make it open another wheel.

**Sharing:** Settings > Share exports a wheel as text you can paste to a friend; importing validates everything and asks you to confirm before accepting any slash commands.

**Rearranging:** press the **E** button in the centre of the wheel for edit mode, then click a slot and click another to swap them. Right-click still edits a slot.

**Smart extras:** Settings > Display has "Switch wheel to suit the situation" (opens the Quick Chat wheel after a whisper, Dungeon / Raid in a group, Social / Guild when solo; change it per wheel on the Wheels tab) and "Play sounds".

**Starting over:** Settings > Display > Reset everything (or `/rw reset all`) restores every wheel and setting to the defaults.

## Where does it send?
By default reactions use *smart reply*:
1. a whisper received in the last 30 seconds -> reply to that whisper
2. guild chat in the last 20 seconds -> guild
3. you're in a group -> raid / party
4. someone spoke in /say recently -> say
5. otherwise -> say

The centre of the wheel always shows the destination ("-> Whisper Bob (12s)"). Click it to cycle to another one.
If the addon is unsure (e.g. guild and party are both active), it asks you where to send after you click.
**Shift+click** a reaction sends to the next-best destination; **Ctrl+click** always asks.
Numbered chat channels (General, Trade...) are never used.

## About /say
The game restricts addons from sending `/say` and `/yell` outdoors unless the message comes from your own keypress (patch 8.2.5 / Classic 1.13.3 onward); whisper, party, raid and guild are not restricted. Whether a given wheel click is accepted can vary, so ReactWheel simply tries to send `/say` every time. If the game refuses, it quietly types the line into your chat box instead (no error popup) and you press Enter. Settings > Targeting > "/say sending" (or `/rw say <auto|prefill>`) can force the chat box every time.

## Emotes
Reactions also play an emote, but by default only when bystanders can see it (say / party / raid), not for whispers or guild.

## Commands
`/rw config` · `/rw wheel <name or number>` · `/rw profile <account|char>` · `/rw say <auto|direct|prefill>` · `/rw debug` · `/rw reset all`

## Development
`tests/run_tests.py` runs the logic tests under Lua 5.1 (`pip install lupa`).

## License
MIT
