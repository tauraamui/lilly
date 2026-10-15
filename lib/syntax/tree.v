// Copyright 2026 The Lilly Edtior contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

module syntax

// The context tree is the structure a grammar gives a document: every context
// a rule pushes (a string, a block comment, an interpolation) is a node, and so
// is every pair of brackets in code. Nodes nest the way the lexer's context
// stack does, with brackets nesting inside whichever context they're in.
//
// Nothing about the tree is stored but a checkpoint every checkpoint_lines
// lines: the line's start state and the nodes open at it. A query lexes
// forward from the nearest checkpoint above, so it costs at most that many
// lines once the checkpoints above it exist.
//
// An edit puts the checkpoints below it aside, moved to where their lines
// went. Most edits change nothing past their own lines, and the first walk to
// reach the first of them, finding the same state and the same nodes open,
// takes them all back, so typing doesn't cost a walk to the end of the file.
//
// Brackets that don't match are recovered from the way most editors do: a
// closing bracket closes the nearest open one of its kind in the same context,
// and any opened after that one with it. One with nothing to close is
// ignored. A context closing closes every bracket left open inside it.
const checkpoint_lines = 256

// LineSource is the document a tree is of. The runes line_runes gives are
// only read until the next call, so a source can decode every line into the
// same buffer.
pub interface LineSource {
mut:
	line_count() int
	line_runes(y int) []rune
}

// Pos is a position in a document, with col counted in runes
pub struct Pos {
pub:
	line int
	col  int
}

pub enum NodeKind as u8 {
	context
	bracket
}

pub struct Node {
pub:
	kind NodeKind
	// name is the grammar's name for a context, or the pair for a bracket:
	// `()`, `[]` or `{}`
	name string
	// scope is a context's scope, and punctuation for a bracket
	scope Scope
	start Pos
	// depth is how many nodes enclose this one
	depth int
}

// Span is a node from an outline, with where it ends if it closes in the
// lines the outline covers
pub struct Span {
pub:
	node Node
	end  ?Pos
}

// Occurrence is one token found by Tree.find
pub struct Occurrence {
pub:
	pos   Pos
	scope Scope
}

// definition_scopes are the scopes a grammar gives a name where it's defined
pub const definition_scopes = [Scope.function_definition, .storage_type_definition,
	.variable_definition]

// Definition is a name defined, found by Tree.definitions
pub struct Definition {
pub:
	pos   Pos
	scope Scope
	name  string
}

const bracket_names = ['()', '[]', '{}']

struct Open {
	kind  NodeKind
	id    u8
	start Pos
	// tied is set on a bracket a context popped through, which closes that
	// context, just below it, when it closes
	tied bool
}

struct Checkpoint {
	line  int
	state State
	open  []Open
}

// unknown_start is where a node starts, in a checkpoint put aside by an edit,
// when it starts on the edited lines: the walk that takes the checkpoint back
// knows where
const unknown_start = Pos{-1, -1}

pub struct Tree {
mut:
	// checkpoints are the starts of lines, in order and checkpoint_lines
	// apart, but for where an edit's were taken back
	checkpoints []Checkpoint
	// stale are the checkpoints below an edit, waiting for a walk to find
	// them unchanged. They're kept last line first, so the walk drops the
	// ones it passes off the end.
	stale []Checkpoint
}

// reset forgets the whole tree, for when every line may have changed or the
// parser's syntax was switched
pub fn (mut t Tree) reset() {
	t.checkpoints.clear()
	t.stale.clear()
}

// edited puts aside the checkpoints an edit may have changed. Lines `first`
// to `last`, counted after the edit, changed; the lines after them moved by
// `delta`.
pub fn (mut t Tree) edited(first int, last int, delta int) {
	if first < 0 {
		t.reset()
		return
	}
	mut kept := []Checkpoint{cap: t.checkpoints.len}
	mut stale := []Checkpoint{cap: t.checkpoints.len + t.stale.len}
	for cp in t.checkpoints {
		if cp.line <= first {
			kept << cp
			continue
		}
		if moved := cp.moved(first, last, delta) {
			stale << moved
		}
	}
	// Finding the first stale checkpoint unchanged vouches for the ones after
	// it only when every edit since they were put aside is above all of them.
	// So the ones still stale from an earlier edit that are below this one are
	// dropped if anything comes before them: valid checkpoints this edit put
	// aside, made after the earlier edit, or stale ones above this edit.
	mut after_others := stale.len > 0
	for i := t.stale.len - 1; i >= 0; i-- {
		cp := t.stale[i]
		if cp.line <= first {
			stale << cp
			after_others = true
			continue
		}
		if after_others {
			break
		}
		if moved := cp.moved(first, last, delta) {
			stale << moved
		}
	}
	t.checkpoints = kept
	t.stale = stale.reverse()
}

// moved_start gives where the context `o` opened, after lines `first` to
// `last` changed and the lines after them moved by `delta`: unknown if it
// opened on a line that changed
fn (o Open) moved_start(first int, last int, delta int) Pos {
	if o.start == unknown_start || o.start.line < first {
		return o.start
	}
	if o.start.line + delta > last {
		return Pos{o.start.line + delta, o.start.col}
	}
	return unknown_start
}

// moved gives a checkpoint where its line went after lines `first` to `last`
// changed and the lines after them moved by `delta`, or none if its line is
// one that changed
fn (cp Checkpoint) moved(first int, last int, delta int) ?Checkpoint {
	line := cp.line + delta
	if line <= last {
		return none
	}
	mut open := []Open{cap: cp.open.len}
	for o in cp.open {
		open << Open{
			...o
			start: o.moved_start(first, last, delta)
		}
	}
	return Checkpoint{
		line:  line
		state: cp.state
		open:  open
	}
}

// covers reports whether the tree's checkpoints reach the last of
// `line_count` lines, so a query anywhere starts within a checkpoint's lines
pub fn (t &Tree) covers(line_count int) bool {
	return line_count <= 0
		|| (t.checkpoints.len > 0 && line_count - 1 - t.checkpoints.last().line < checkpoint_lines)
}

// warm walks on `lines` lines from the last checkpoint, leaving checkpoints
// as it goes, so a later query that far down doesn't walk from the top. It
// walks at least checkpoint_lines, which places the next checkpoint: any
// fewer would place none, and the next warm would walk the same lines again.
// It reports whether the checkpoints then reach the last line.
pub fn (mut t Tree) warm(mut parser Parser, mut src LineSource, lines int) bool {
	count := src.line_count()
	from := if t.checkpoints.len == 0 { 0 } else { t.checkpoints.last().line }
	step := if lines > checkpoint_lines { lines } else { checkpoint_lines }
	mut w := t.walk_to(mut parser, mut src, from + step) or { return true }
	w.done()
	return t.covers(count)
}

// ancestors gives the nodes that contain `pos`, outermost first. A node
// contains the positions from its first rune up to, not including, the one
// after its last.
pub fn (mut t Tree) ancestors(mut parser Parser, mut src LineSource, pos Pos) []Node {
	mut w := t.walk_to(mut parser, mut src, pos.line) or { return []Node{} }
	w.apply_through(pos.col)
	nodes := w.nodes()
	w.done()
	return nodes
}

// node_at gives the innermost node that contains `pos`
pub fn (mut t Tree) node_at(mut parser Parser, mut src LineSource, pos Pos) ?Node {
	nodes := t.ancestors(mut parser, mut src, pos)
	if nodes.len == 0 {
		return none
	}
	return nodes.last()
}

// enclosing gives the innermost node named `name` that contains `pos`
pub fn (mut t Tree) enclosing(mut parser Parser, mut src LineSource, pos Pos, name string) ?Node {
	nodes := t.ancestors(mut parser, mut src, pos)
	for i := nodes.len - 1; i >= 0; i-- {
		if nodes[i].name == name {
			return nodes[i]
		}
	}
	return none
}

// end_of gives the position just past `node`'s last rune. It looks no further
// than `max_lines` lines below the node's start, and gives none if the node
// doesn't close by then or isn't in the tree.
pub fn (mut t Tree) end_of(mut parser Parser, mut src LineSource, node Node, max_lines int) ?Pos {
	mut w := t.walk_into(mut parser, mut src, node) or { return none }
	defer {
		w.done()
	}
	// the walk goes on from the last checkpoint the node is open at, as a
	// block a whole file long would otherwise cost a walk over all of it
	k := t.last_checkpoint_open(node, node.start.line + max_lines)
	if k >= 0 && t.checkpoints[k].line > w.line {
		w.start_at(k)
	}
	for {
		for w.next < w.parser.events.len {
			e := w.parser.events[w.next]
			w.apply_next()
			if !w.has(node) {
				return Pos{w.line, e.col}
			}
		}
		if w.line - node.start.line >= max_lines || !w.next_line() {
			return none
		}
	}
	return none
}

// last_checkpoint_open gives the index of the last checkpoint no further
// down than line `last` that `node` is open at, or -1 if it's open at none.
// A node stays open from where it starts to where it ends, so the
// checkpoints it's open at are a run of those below its start line.
fn (t &Tree) last_checkpoint_open(node Node, last int) int {
	if t.checkpoints.len == 0 {
		return -1
	}
	mut lo := t.checkpoint_before(node.start.line) + 1
	mut hi := t.checkpoint_before(last)
	if lo > hi || !t.checkpoints[lo].holds(node) {
		return -1
	}
	for lo < hi {
		mid := (lo + hi + 1) / 2
		if t.checkpoints[mid].holds(node) {
			lo = mid
			continue
		}
		hi = mid - 1
	}
	return lo
}

// holds reports whether `node` is open at the checkpoint
fn (cp Checkpoint) holds(node Node) bool {
	return node.depth < cp.open.len && cp.open[node.depth].start == node.start
}

// children gives the nodes directly inside `node`, looking no further than
// `max_lines` lines below its start
pub fn (mut t Tree) children(mut parser Parser, mut src LineSource, node Node, max_lines int) []Node {
	mut found := []Node{}
	mut w := t.walk_into(mut parser, mut src, node) or { return found }
	defer {
		w.done()
	}
	for {
		for w.next < w.parser.events.len {
			e := w.parser.events[w.next]
			w.apply_next()
			if !w.has(node) {
				return found
			}
			if e.open && w.open.len == node.depth + 2 {
				found << w.node(node.depth + 1)
			}
		}
		if w.line - node.start.line >= max_lines || !w.next_line() {
			return found
		}
	}
	return found
}

// find gives every token on lines `first` to `last` whose text is `word` and,
// unless `scopes` is empty, whose scope is one of them. Searching for a
// function's name with [.function] finds the places it's called, and the
// tree's nodes give the range to look in, e.g. the function around the
// cursor.
pub fn (mut t Tree) find(mut parser Parser, mut src LineSource, word string, scopes []Scope, first int, last int) []Occurrence {
	mut found := []Occurrence{}
	target := word.runes()
	if target.len == 0 {
		return found
	}
	mut w := t.walk_to(mut parser, mut src, first) or { return found }
	defer {
		w.done()
	}
	for w.line <= last {
		// lex the line again for its tokens, from the same start state. The
		// line's events stay as they were, and the walk moves on from
		// end_state, so this doesn't disturb it.
		w.parser.reset()
		w.parser.set_state(w.state)
		w.parser.lex(w.runes, true)
		for tok in w.parser.tokens {
			if tok.end - tok.start != target.len || (scopes.len > 0 && tok.scope !in scopes) {
				continue
			}
			if w.runes[tok.start..tok.end] == target {
				found << Occurrence{
					pos:   Pos{w.line, tok.start}
					scope: tok.scope
				}
			}
		}
		if !w.next_line() {
			break
		}
	}
	return found
}

// definitions gives every name defined on lines `first` to `last`, e.g. the
// functions, types and variables, in document order
pub fn (mut t Tree) definitions(mut parser Parser, mut src LineSource, first int, last int) []Definition {
	mut found := []Definition{}
	mut w := t.walk_to(mut parser, mut src, first) or { return found }
	defer {
		w.done()
	}
	for w.line <= last {
		// lexed again for its tokens, as find does
		w.parser.reset()
		w.parser.set_state(w.state)
		w.parser.lex(w.runes, true)
		for tok in w.parser.tokens {
			if tok.scope in definition_scopes {
				found << Definition{
					pos:   Pos{w.line, tok.start}
					scope: tok.scope
					name:  w.runes[tok.start..tok.end].string()
				}
			}
		}
		if !w.next_line() {
			break
		}
	}
	return found
}

// outline gives, in document order, the nodes open at the start of line
// `first` and every node that opens on lines `first` to `last`, each with
// its end if it closes on those lines
pub fn (mut t Tree) outline(mut parser Parser, mut src LineSource, first int, last int) []Span {
	return t.spans(mut parser, mut src, first, last, false)
}

// blocks gives the spans outline does that run over more than one line: the
// ones that end on a later line than they start on, or don't end on lines
// `first` to `last`. Folding wants these alone, and a whole file's worth of
// every node would be most of its brackets.
pub fn (mut t Tree) blocks(mut parser Parser, mut src LineSource, first int, last int) []Span {
	return t.spans(mut parser, mut src, first, last, true)
}

fn (mut t Tree) spans(mut parser Parser, mut src LineSource, first int, last int, blocks_only bool) []Span {
	mut nodes := []Node{}
	mut ends := []?Pos{}
	mut w := t.walk_to(mut parser, mut src, first) or { return []Span{} }
	// open_spans[d] is the index in nodes of the node open at depth d
	mut open_spans := []int{}
	for depth in 0 .. w.open.len {
		nodes << w.node(depth)
		ends << ?Pos(none)
		open_spans << nodes.len - 1
	}
	for {
		for w.next < w.parser.events.len {
			e := w.parser.events[w.next]
			w.apply_next()
			// one event can close nodes and open one, as a tie does
			for open_spans.len > 0 && !w.has(nodes[open_spans.last()]) {
				i := open_spans.last()
				open_spans.delete_last()
				if blocks_only && nodes[i].start.line == w.line {
					// whatever opened after it was inside it, so it's on
					// one line too and went the same way, leaving it last
					nodes.delete_last()
					ends.delete_last()
					continue
				}
				ends[i] = Pos{w.line, e.col}
			}
			for open_spans.len < w.open.len {
				nodes << w.node(open_spans.len)
				ends << ?Pos(none)
				open_spans << nodes.len - 1
			}
		}
		if w.line >= last || !w.next_line() {
			break
		}
	}
	w.done()
	mut spans := []Span{cap: nodes.len}
	for i, node in nodes {
		spans << Span{
			node: node
			end:  ends[i]
		}
	}
	return spans
}

// token_at gives the token `pos` is in, which for plain text is a token of
// its context's scope
pub fn (mut t Tree) token_at(mut parser Parser, mut src LineSource, pos Pos) ?Token {
	mut w := t.walk_to(mut parser, mut src, pos.line) or { return none }
	defer {
		w.done()
	}
	if w.line != pos.line {
		return none
	}
	w.parser.reset()
	w.parser.set_state(w.state)
	w.parser.lex(w.runes, true)
	for tok in w.parser.tokens {
		if tok.start <= pos.col && pos.col < tok.end {
			return tok
		}
	}
	return none
}

// Walker steps through the tree's events in document order, keeping the
// nodes open at the point it has reached
struct Walker {
mut:
	tree   &Tree
	parser &Parser
	src    LineSource
	lines  int
	// line is the line whose events are in parser.events, next the first of
	// them not applied yet
	line  int
	next  int
	runes []rune
	// state is the start state of line, end_state the one after it
	state     State
	end_state State
	open      []Open
}

// walk_to starts a walk at the start of line `y`, from the nearest
// checkpoint above it
fn (mut t Tree) walk_to(mut parser Parser, mut src LineSource, y int) ?Walker {
	lines := src.line_count()
	if lines == 0 || y < 0 {
		return none
	}
	target := if y < lines { y } else { lines - 1 }
	if t.checkpoints.len == 0 {
		parser.reset()
		t.checkpoints << Checkpoint{
			state: parser.current_state()
		}
	}
	mut w := Walker{
		tree:   unsafe { &t }
		parser: unsafe { &parser }
		src:    src
		lines:  lines
	}
	w.start_at(t.checkpoint_before(target))
	for w.line < target {
		w.next_line()
		// a walk that took back an edit's checkpoints goes on from the one
		// nearest the target
		if t.checkpoints.last().line > w.line {
			k := t.checkpoint_before(target)
			if t.checkpoints[k].line > w.line {
				w.start_at(k)
			}
		}
	}
	return w
}

// checkpoint_before gives the index of the last checkpoint at or above line
// `y`
fn (t &Tree) checkpoint_before(y int) int {
	mut lo := 0
	mut hi := t.checkpoints.len - 1
	for lo < hi {
		mid := (lo + hi + 1) / 2
		if t.checkpoints[mid].line <= y {
			lo = mid
			continue
		}
		hi = mid - 1
	}
	return lo
}

// start_at moves the walk to checkpoint `k`
fn (mut w Walker) start_at(k int) {
	cp := w.tree.checkpoints[k]
	w.line = cp.line
	w.state = cp.state
	w.open = cp.open.clone()
	w.load()
}

// walk_into starts a walk just after `node` opened, or gives none if it no
// longer opens where it says
fn (mut t Tree) walk_into(mut parser Parser, mut src LineSource, node Node) ?Walker {
	mut w := t.walk_to(mut parser, mut src, node.start.line)?
	if w.line != node.start.line {
		w.done()
		return none
	}
	w.apply_through(node.start.col)
	if w.open.len <= node.depth || w.open[node.depth].start != node.start
		|| w.node(node.depth).name != node.name {
		w.done()
		return none
	}
	return w
}

// load lexes the walker's line, recording its events
fn (mut w Walker) load() {
	w.runes = w.src.line_runes(w.line)
	w.parser.reset()
	w.parser.set_state(w.state)
	w.parser.record = true
	w.parser.lex(w.runes, false)
	w.parser.record = false
	w.end_state = w.parser.current_state()
	w.next = 0
}

// next_line applies the rest of the line's events and moves to the start of
// the next line, leaving a checkpoint there if it's the next one due. It
// returns false at the last line.
fn (mut w Walker) next_line() bool {
	if w.line + 1 >= w.lines {
		return false
	}
	for w.next < w.parser.events.len {
		w.apply_next()
	}
	w.line++
	w.state = w.end_state
	w.reached()
	w.load()
	return true
}

// reached keeps the tree's checkpoints at the start of a line past the last of
// them: taking back an edit's, if the walk finds the first unchanged, or
// leaving a new one when it's due
fn (mut w Walker) reached() {
	mut t := w.tree
	if w.line <= t.checkpoints.last().line {
		return
	}
	for t.stale.len > 0 && t.stale.last().line < w.line {
		t.stale.delete_last()
	}
	if t.stale.len > 0 && t.stale.last().line == w.line {
		if w.unchanged(t.stale.last()) {
			w.take_back_stale()
			return
		}
		t.stale.delete_last()
	}
	if w.line - t.checkpoints.last().line >= checkpoint_lines {
		t.checkpoints << Checkpoint{
			line:  w.line
			state: w.state
			open:  w.open.clone()
		}
	}
}

// unchanged reports whether the walk, at a checkpoint's line, has the state
// and nodes open the checkpoint does. A node that starts on edited lines can
// have moved along its line, so only what it is has to match.
fn (w &Walker) unchanged(cp Checkpoint) bool {
	if cp.state != w.state || cp.open.len != w.open.len {
		return false
	}
	for d, o in cp.open {
		now := w.open[d]
		if o.kind != now.kind || o.id != now.id || o.tied != now.tied
			|| (o.start != unknown_start && o.start != now.start) {
			return false
		}
	}
	return true
}

// take_back_stale makes the stale checkpoints checkpoints again, the first
// being where the walk is. A node open at a later one that starts on edited
// lines is open here too, at the same depth, so the walk knows where it
// starts.
fn (mut w Walker) take_back_stale() {
	mut t := w.tree
	for i := t.stale.len - 1; i >= 0; i-- {
		cp := t.stale[i]
		mut open := cp.open.clone()
		for d in 0 .. open.len {
			if open[d].start == unknown_start {
				if d >= w.open.len {
					t.stale.clear()
					return
				}
				open[d] = Open{
					...open[d]
					start: w.open[d].start
				}
			}
		}
		t.checkpoints << Checkpoint{
			...cp
			open: open
		}
	}
	t.stale.clear()
}

// apply_through applies the line's events up to and including column `col`
fn (mut w Walker) apply_through(col int) {
	for w.next < w.parser.events.len && w.parser.events[w.next].col <= col {
		w.apply_next()
	}
}

fn (mut w Walker) apply_next() {
	e := w.parser.events[w.next]
	w.next++
	kind := if e.bracket { NodeKind.bracket } else { NodeKind.context }
	if e.ties {
		// the context the lexer popped runs on through the bracket, closing
		// whatever was left open inside it before the bracket
		for k := w.open.len - 1; k >= 0; k-- {
			if w.open[k].kind == .context && !w.open[k].tied {
				w.open.trim(k + 1)
				w.open[k] = Open{
					...w.open[k]
					tied: true
				}
				break
			}
		}
	}
	if e.open {
		w.open << Open{
			kind:  kind
			id:    e.id
			start: Pos{w.line, e.col}
			tied:  e.ties
		}
		return
	}
	for k := w.open.len - 1; k >= 0; k-- {
		o := w.open[k]
		if e.bracket && o.kind == .context {
			// a bracket doesn't close anything outside its context
			return
		}
		// a tied context is gone from the lexer's stack, so it's never the one
		// a context closing is: that's further out, and closes it too
		if o.kind == .context && o.tied {
			continue
		}
		if o.kind == kind && o.id == e.id {
			// a tied bracket closes the context tied to it, just below it
			w.open.trim(if o.tied { k - 1 } else { k })
			return
		}
	}
}

// has reports whether `node` is still open where the walk has reached
fn (w &Walker) has(node Node) bool {
	return node.depth < w.open.len && w.open[node.depth].start == node.start
}

fn (w &Walker) node(depth int) Node {
	o := w.open[depth]
	if o.kind == .bracket {
		return Node{
			kind:  o.kind
			name:  bracket_names[o.id]
			scope: .punctuation
			start: o.start
			depth: depth
		}
	}
	return Node{
		kind:  o.kind
		name:  w.parser.info.names[o.id]
		scope: w.parser.info.scopes[o.id]
		start: o.start
		depth: depth
	}
}

fn (w &Walker) nodes() []Node {
	mut nodes := []Node{cap: w.open.len}
	for depth in 0 .. w.open.len {
		nodes << w.node(depth)
	}
	return nodes
}

// done leaves the parser as a query found it: reset, with nothing recorded
fn (mut w Walker) done() {
	w.parser.record = false
	w.parser.events.clear()
	w.parser.reset()
}
