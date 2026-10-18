# TODO: feature parity with the legacy editor

The legacy editor has been removed. The `legacy:` references below point into
it as of commit `3fc0ce28`, e.g. `git show 3fc0ce28:editor.v`; the files there
named `editor.v`, `editor_workspace.v` and `lib/documents/document.v` are the
legacy implementation, not the current ones. The editor is still missing
several features the legacy one had.

__List Task Status Key__
complete = x
deferred = ~
in-progress = >

## 1. Fix data-loss bug (do first)
- [~] `yy` / `cc` currently **delete the line** instead of yanking/entering
      change mode. `execute_action_normal`'s `'line'` branch ignores
      `action.operator` and unconditionally calls `delete_line`.

## 2. Motions / modal editing
- [x] `$` (end of line) — wired into `apply_motion`/`motion_range` (`motions.v`),
      reusing the existing `Controller.jump_cursor_to_line_end` primitive.
      Covered by `motions_dollar_test.v`.
- [x] `0` (start of line), `^` (first non-blank) — need new `Controller`/
      `TextBuffer` primitives (legacy: `document.v:263,267`) plus chord dispatch
      wiring (chord parsing for both already exists in `chords.v`).
- [x] Goal-column ("curswant") memory for vertical motion — `TextBuffer.goal_column`
      now persists across a run of vertical moves and resets on any other
      cursor-moving op (`text_buf.v`). Covered by `text_buf_test.v`.
- [x] `x` (delete char under cursor) — `TextBuffer.delete_char_at` (`text_buf.v`)
      plus `Controller.delete_char_at` and chord dispatch wiring in
      `execute_action_normal` (`editor.v`). Unlike the general-purpose
      `delete()` used by insert-mode Delete, it never joins into the next
      line on an empty line. Covered by `motions_x_test.v`.
- [x] `I` (insert at first non-blank), `A` (append at end of line) — depend on the
      line-start/line-end primitives above.
- [x] `gg` / `G` (jump to first/last line) — new `TextBuffer.jump_cursor_to_line`/
      `Controller.jump_cursor_to_line` primitive (lands on first non-blank,
      like `^`), wired into `apply_motion` (`motions.v`); chord parsing for
      both already existed in `chords.v`. Covered by `motions_gg_g_test.v`.
- [x] `zz` (center viewport on cursor line, incl. numeric `zz` goto-line) — no
      `goto_line`/`center_cursor_line` on `EditorModel`.
- [~] `p` / `P` (paste before/after) — not wired; depends on register (see §3).
- [x] `ctrl+u` / `ctrl+d` half-page scroll — not wired in normal mode.
- [x] Forward `delete` key in normal mode — not wired.
- [>] Auto-clear whitespace-only line when leaving insert → normal — no
      equivalent yet (legacy: `editor.v:579-594`).
- [ ] Visual mode `y` / `c` — explicitly stubbed (`TODO` in `apply_operator`,
      returns `false`). Only visual `d` currently works (both charwise and,
      as of `visual_linewise`, linewise).
- [x] `V` (visual-line mode) — implemented: `visual_linewise` state, dedicated
      rendering, and `apply_linewise_operator` (currently `d` only, matching
      the charwise `y`/`c` gap above). Covered by `editor_visual_test.v`.

## 3. Clipboard / registers
- [ ] Entire yank/register subsystem is missing from `EditorModel`/`Controller`/
      `TextBuffer` — no field, no storage, nothing.
- [ ] Reintroduce `clipboard.Manager` wiring (system clipboard + OSC52 fallback)
      into `EditorModel` once registers exist.

## 4. File I/O
- [ ] `TextBuffer.write_to_path` / `Controller.write_to_disk` never stat/restore
      original file permissions before the atomic write (legacy did via `os.chmod`).
      Real regression for executables / restricted-mode files.

## 5. Config
- [ ] `expand_tabs` isn't plumbed into `EditorWorkspaceConfig`/`EditorModel` —
      always inserts a literal `\t` regardless of config.

## 6. Command / leader surface
- [ ] Re-add missing `:` commands: `:debug`, `:version`, `:wq`/`:x`, `:new`,
      numeric line-jump (`:123`).
- [ ] Re-add `<leader>nf` (new file dialog) leader sequence.

## 7. Minor / lower priority
- [ ] The legacy `Controller.free()` cleanup has no counterpart (likely low-impact, map GC
      should cover it, but confirm before dropping).
- [ ] Decide on auto-close symbol parity: the auto-close (buffer layer) is
      missing `"` and `` ` `` (legacy had them), and fires unconditionally even
      without syntax loaded (legacy gated on `lang_syn.name.len > 0`). Confirm this
      is intentional.

## 8. Test coverage
- [ ] Add tests exercising `EditorModel` / `EditorWorkspaceModel` / `Controller`
      directly — currently none exist.
