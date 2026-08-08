# TODO: v2 feature parity before decommissioning v1

V2 (`editor2.v`, `editor_workspace2.v`, `Controller2`) is already the live path from
`main.v` — v1 (`editor.v`, `editor_workspace.v`, `documents.Controller`) is dead code
at runtime, but v2 is missing/regresses several features v1 has. Also note: zero
automated tests currently exercise v2 (`editor_auto_close_test.v` and
`editor_line_jump_test.v` only construct v1 types despite their names) — add v2
coverage before/while removing v1.

__List Task Status Key__
complete = x
deferred = ~
in-progress = >

## 1. Fix data-loss bug (do first)
- [~] `yy` / `cc` currently **delete the line** in v2 instead of yanking/entering
      change mode. `execute_action_normal`'s `'line'` branch ignores
      `action.operator` and unconditionally calls `delete_line`.

## 2. Motions / modal editing
- [x] `$` (end of line) — wired into `apply_motion`/`motion_range` (`motions.v`),
      reusing the existing `Controller2.jump_cursor_to_line_end` primitive.
      Covered by `motions_dollar_test.v`.
- [x] `0` (start of line), `^` (first non-blank) — need new `Controller2`/
      `TextBuffer` primitives (v1: `document.v:263,267`) plus chord dispatch
      wiring (chord parsing for both already exists in `chords.v`).
- [x] Goal-column ("curswant") memory for vertical motion — `TextBuffer.goal_column`
      now persists across a run of vertical moves and resets on any other
      cursor-moving op (`text_buf.v`). Covered by `text_buf_test.v`.
- [x] `x` (delete char under cursor) — `TextBuffer.delete_char_at` (`text_buf.v`)
      plus `Controller2.delete_char_at` and chord dispatch wiring in
      `execute_action_normal` (`editor2.v`). Unlike the general-purpose
      `delete()` used by insert-mode Delete, it never joins into the next
      line on an empty line. Covered by `motions_x_test.v`.
- [x] `I` (insert at first non-blank), `A` (append at end of line) — depend on the
      line-start/line-end primitives above.
- [x] `gg` / `G` (jump to first/last line) — new `TextBuffer.jump_cursor_to_line`/
      `Controller2.jump_cursor_to_line` primitive (lands on first non-blank,
      like `^`), wired into `apply_motion` (`motions.v`); chord parsing for
      both already existed in `chords.v`. Covered by `motions_gg_g_test.v`.
- [x] `zz` (center viewport on cursor line, incl. numeric `zz` goto-line) — no
      `goto_line`/`center_cursor_line` on `EditorModel2`.
- [~] `p` / `P` (paste before/after) — not wired; depends on register (see §3).
- [x] `ctrl+u` / `ctrl+d` half-page scroll — not wired in v2 normal mode.
- [x] Forward `delete` key in normal mode — not wired in v2.
- [>] Auto-clear whitespace-only line when leaving insert → normal — no v2
      equivalent (v1: `editor.v:579-594`).
- [ ] Visual mode `y` / `c` — explicitly stubbed (`TODO` in `apply_operator`,
      returns `false`). Only visual `d` currently works (both charwise and,
      as of `visual_linewise`, linewise).
- [x] `V` (visual-line mode) — implemented: `visual_linewise` state, dedicated
      rendering, and `apply_linewise_operator` (currently `d` only, matching
      the charwise `y`/`c` gap above). Covered by `editor2_visual_test.v`.

## 3. Clipboard / registers
- [ ] Entire yank/register subsystem is missing from `EditorModel2`/`Controller2`/
      `TextBuffer` — no field, no storage, nothing.
- [ ] Reintroduce `clipboard.Manager` wiring (system clipboard + OSC52 fallback)
      into `EditorModel2` once registers exist.

## 4. File I/O
- [ ] `TextBuffer.write_to_path` / `Controller2.write_to_disk` never stat/restore
      original file permissions before the atomic write (v1 does via `os.chmod`).
      Real regression for executables / restricted-mode files.

## 5. Config
- [ ] `expand_tabs` isn't plumbed into `EditorWorkspaceConfig`/`EditorModel2` — v2
      always inserts a literal `\t` regardless of config.

## 6. Command / leader surface
- [ ] Re-add missing `:` commands: `:debug`, `:version`, `:wq`/`:x`, `:new`,
      numeric line-jump (`:123`).
- [ ] Re-add `<leader>nf` (new file dialog) leader sequence.

## 7. Minor / lower priority
- [ ] `Controller.free()` cleanup has no v2 counterpart (likely low-impact, map GC
      should cover it, but confirm before dropping).
- [ ] Decide on auto-close symbol parity: v2's auto-close (buffer layer) is
      missing `"` and `` ` `` (v1 has them), and fires unconditionally even
      without syntax loaded (v1 gates on `lang_syn.name.len > 0`). Confirm this
      is intentional before removing v1's version.

## 8. Test coverage
- [ ] Add tests exercising `EditorModel2` / `EditorWorkspaceModel2` / `Controller2`
      directly — currently none exist.
