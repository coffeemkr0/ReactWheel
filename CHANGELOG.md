# Changelog

## 1.0.4
- **Fix: "attempt to perform string conversion on a secret string value" errors.** In combat and in some instances the game hides chat sender names and message text from addons. ReactWheel now checks for hidden values before touching them: group, guild and say chat still count as "someone spoke" without the name, a whisper from a hidden name is skipped (there is nobody readable to reply to), and a hidden Battle.net name is looked up by account id.

## 1.0.3
- **Battle.net whispers:** replying to a Battle.net friend's whisper now works. The addon tracks those whispers and answers them through Battle.net, instead of replying to the last character whisper.

## 1.0.2
- **Wheel memory:** with "Switch wheel when my situation changes" on, the wheel now only switches when your situation actually changes (whisper, group, solo). Before, it jumped back to the situation's wheel on every open and forgot the one you had picked. The next / previous wheel key bindings also start from the wheel you used last.
- **Key bindings button:** Settings > Display > "Key bindings..." (and "Set key..." in the welcome window) now opens the game's key bindings on newer clients; it used to do nothing.
- **Targeting tab layout:** the option buttons no longer run into the right-hand column or cover the "where would this go right now" text.

## 1.0.1
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
