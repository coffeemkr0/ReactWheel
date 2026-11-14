# Changelog

## 1.0.1
- **Wheel memory:** with "switch wheel when my situation changes" on, the wheel now only switches when your situation actually changes (whisper, group, solo). Before, it jumped back to the situation's wheel on every open and forgot the one you had picked.
- **Right-click menu:** right-clicking a slice now opens a small menu with **Slot settings...** (the slot editor) and **Swap with another slot...** (click the slice to swap with).
- **Removed the "E" edit button** from the centre of the wheel; swapping now lives in the right-click menu.
- **Social / Guild wheel:** `welcome` is now `my bad` (plays the apologize emote). Existing wheels are updated only if that slice was never changed.

## 1.0.0
First full release.

- **Radial reaction wheel:** press a key, click a reaction. Left-click sends, right-click edits, Esc closes.
- **Multiple wheels** (4-12 slices each) with four ready-made ones: Quick Chat, Dungeon / Raid, Social / Guild, Emotes. Scroll or use the centre arrows to switch.
- **Smart reply:** picks whisper, guild, raid/party or say from recent chat, shows the destination in the centre, asks when unsure, with Shift/Ctrl-click and click-to-cycle overrides. Fully configurable order and timings.
- **Emotes** that play with reactions, only where bystanders can see them by default; configurable per reaction.
- **Slot editor:** label, text, emote, slash command, destination, icon, colour, sub-wheels, test button.
- **Settings window** (Wheels, Display, Targeting, Emotes, Share), minimap button, in-wheel edit mode (swap slices), per-character or shared wheels.
- **Import / export** of wheels as text, with validation.
- **Extras:** adjustable sizes, optional sounds, automatic wheel switching by situation, pause between reactions, first-run welcome, **Reset everything**.
- **`/say` handling:** tries to send directly; if the game refuses, quietly puts the line in your chat box.
- User-guide README and logic tests.
