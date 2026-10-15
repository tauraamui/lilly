# Grammars

Each `<id>.kdl` here generates `lib/syntax/lexer_<id>.v`. The generated files
are committed. After editing a grammar, regenerate them:

    v run make.vsh syntax-gen

CI fails if a generated lexer is out of date (`v run make.vsh verify-syntax-gen`).

## Format

```kdl
name "V"
extensions ".v" ".vsh"

// words give identifiers matched by a `words=#true` rule their scope
words "keyword.control" if else for return

// the first context must be "main"; a line starts in it
context "main" {
    rule #"//.*"# scope="comment"
    rule "\"" scope="string" push="double"
    rule #"[A-Za-z_]\w*"# words=#true
    rule #"[A-Za-z_]\w*"# scope="variable"
}

// text no rule matches takes the context's scope
context "double" scope="string" {
    rule #"\\."# scope="string.escape"
    rule "\"" pop=#true
}
```

- A context tries its rules in order at each position, and the first match
  wins. Text between matches is plain text in the context's scope.
- `rule` properties: `scope`, which defaults to the context's scope, and one
  of `push="ctx"`, `set="ctx"`, `pop=#true` or `embed="id"` (with an
  `escape`, described under embedding below). A popping rule can add
  `through=#true`, described under the context tree below.
- A `words=#true` rule only matches text that is in a word list, and takes
  that list's scope.
- `include "ctx"` splices another context's rules in at that point.
- `pop_at_eol=#true` on a context pops it at the end of each line, e.g. for
  strings that can't span lines.
- Scopes are the names in `lib/syntax/scope.v`, written with dots
  (`keyword.control`). Themes colour them through `syntax_<scope>` fields,
  falling back to the parent scope.

## Embedding another grammar

A rule with `embed="<id>"` lexes what follows with another grammar, the one
in `<id>.kdl`, until its `escape` pattern matches:

```kdl
rule #"^```v.*"# scope="punctuation" embed="v" escape=#"^```\s*$"#
```

syntaxgen copies the embedded grammar's contexts in after the grammar's own,
each copy trying the escape before calling the embedded grammar's generated
function for the context, so no lexer code is duplicated. The escape is tried
at every position in every copied context, so it ends the embedded code
whatever was left open in it, like an unclosed block comment. It doesn't cut a
token short, though: a match the embedded grammar makes runs on over an escape
inside it. Plain text in the embedded code stops wherever the escape could
start.

The escape takes the embedding rule's scope. The copy of the embedded
grammar's `main` is named after it (`v`), and is the node the embedded code
makes in the context tree, from the start of the embedding rule's match to the
end of the escape's. One grammar can embed many, with up to 255 contexts in
all, but an embedded grammar can't embed others itself.

## The context tree

Grammars also give the document its structure, which `lib/syntax/tree.v` turns
into a tree. Each context a rule pushes is a node, running from the start of
the match that pushed it to the end of the match that popped it. So is every
pair of brackets (`()`, `[]`, `{}`) in code. Brackets count when they're plain
text or matched by a rule with no scope, a `punctuation` scope or an `operator`
scope, unless they're inside a context scoped as a comment or a string.

A context makes a better node than its brackets would when the grammar can say
what the node is, like a function's parameters or body. The context's name is
what queries look for. A context pushed by a bracket, like a parameter list
pushed by `(`, is a bracket node as well, just inside the context's node, so
bracket matching and indenting work in it the same.

A construct with a body, like a function, is a context from its keyword to
the opening brace, popped by a rule with `through=#true`:

```kdl
context "function" pop_at_eol=#true {
    rule #"\{"# pop=#true through=#true
    ...
}
```

The lexer is back in the context around it for the body, so the body lexes as
it would without the function, but the function's node runs on through the
braces, closing when they do. Its name is a definition scope, such as
`function.definition`, which `find` can tell from a call's `function`.

Patterns are regular-expression-like but match the way a PEG does, which is
what lets them compile to plain V. Repeats never give characters back, and
`a|b` takes the first alternative that matches. The syntax is documented in
`cmd/syntaxgen/pattern.v`. Raw strings (`#"..."#`) save escaping backslashes.
Put each rule on its own line. kdlv currently fails to parse a block written on
one line, like `context "x" { rule "a" }`.
