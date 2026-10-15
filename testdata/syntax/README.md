# Syntax highlighting stress files

One file per grammar in `lib/syntax/grammars/`. Each one exercises the
contexts, push/pop transitions and word lists of its grammar, plus constructs
the grammar does not model (marked `KNOWN GAP` in a comment) so you can see how
the lexer degrades and whether it recovers on the following lines.

Things worth checking in the editor:

- multi-line contexts (block comments, raw/triple/template strings, POD) colour
  every line, and the line after the closing delimiter is back in `main`
- jumping into the middle of a long multi-line context (`G`, then scrolling up)
  gives the same colours as scrolling down from the top, since line states are
  lexed lazily down to the viewport
- editing the opening delimiter of a multi-line context re-colours the lines
  below it, and undoing restores them
- nested contexts (Rust/V block comments, JS/TS/V interpolation with braces)
  pop back to the right level

Note: `*.js` is in `.gitignore`, so `javascript.js` needs `git add -f`.
