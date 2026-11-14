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

## Emotes
Reactions also play an emote, but by default only when bystanders can see it (say / party / raid), not for whispers or guild.

## Commands
`/rw config` · `/rw wheel <name or number>` · `/rw profile <account|char>` · `/rw debug` · `/rw reset`

## Development
`tests/run_tests.py` runs the logic tests under Lua 5.1 (`pip install lupa`).

## License
MIT
