# ReactWheel

A radial quick-reaction menu for WoW chat, inspired by Teams reactions.
Hold a key, flick the mouse toward a reaction, release — it's sent to whoever last spoke to you
(whisper, party, raid, or say only — never guild or channels).

Defaults: thumbs up (sends `√`), thumbs down (sends `▼`), `♥  LOL  GG  thanks!  omw  what?`

## Install
Copy the `ReactWheel` folder into `Interface/AddOns/`.

## Use
1. Esc > Key Bindings > ReactWheel: bind "Show reaction wheel (hold)".
2. Hold the key, move the mouse toward a slice (or click one), release to send.

## Commands
- `/rw set <1-8> <text>` customise a slot (1 = top, clockwise)
  Use `{up}` / `{down}` as the text to get the thumbs icons.
- `/rw reset` restore defaults
- `/rw reply <auto|party|raid|say>` force the destination

## Compatibility
Uses `## Interface: 16001` and is written in Lua 5.0-compatible style.
If your client uses a different interface number, edit the `.toc`. Untested in-game — reports welcome.

## License
MIT
