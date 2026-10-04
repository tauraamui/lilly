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

module main

import runtime
import time
import bobatea as tea
import lib.boba
import lib.documents
import lib.palette

// rss_sample_interval_ms throttles the only part of sampling that costs a
// syscall. The GC counters are plain reads and are taken every frame.
const rss_sample_interval_ms = i64(250)

// max_hot_ops is how many message types the panel lists. The tail is folded
// into a single "other" row so the totals still add up.
const max_hot_ops = 8

// msg_label names the message type a measurement belongs to.
//
// This is deliberately a hand-written table rather than msg.type_name(). The
// generated type_name() for an interface with this many implementors expands
// into one long if-chain, and the v3 C backend segfaults generating it once a
// test build has registered every type in the binary (the plain build is
// fine). A match is also allocation-free, which type_name() is not guaranteed
// to be, and this runs on every message.
//
// Types not listed here land in 'unlabelled'. The panel shows that bucket's
// size, so if it ever grows large enough to hide something, add the type.
fn msg_label(msg tea.Msg) string {
	return match msg {
		// per-frame and per-keystroke traffic, where churn accumulates
		tea.KeyMsg { 'KeyMsg' }
		tea.NoopMsg { 'NoopMsg' }
		tea.TickMsg { 'TickMsg' }
		tea.ResizedMsg { 'ResizedMsg' }
		tea.ClearScreenMsg { 'ClearScreenMsg' }
		boba.CursorBlinkMsg { 'CursorBlinkMsg' }
		// the heavyweight operations, where a jump in the live set comes from
		OpenFileMsg { 'OpenFileMsg' }
		CreateAndOpenFileMsg { 'CreateAndOpenFileMsg' }
		OpenEditorMsg { 'OpenEditorMsg' }
		OpenEditorWorkspaceMsg { 'OpenEditorWorkspaceMsg' }
		OpenEditorInSplitMsg { 'OpenEditorInSplitMsg' }
		VerticalSplitMsg { 'VerticalSplitMsg' }
		WriteToDiskMsg { 'WriteToDiskMsg' }
		SyntaxLoadedMsg { 'SyntaxLoadedMsg' }
		LoadFilesMsg { 'LoadFilesMsg' }
		FilterFilesMsg { 'FilterFilesMsg' }
		EditorModelKeyMsg { 'EditorModelKeyMsg' }
		EditorModel2Msg { 'EditorModel2Msg' }
		EditorDataResultMsg { 'EditorDataResultMsg' }
		EditorData2ResultMsg { 'EditorData2ResultMsg' }
		QueryEditorDataMsg { 'QueryEditorDataMsg' }
		QueryEditorData2Msg { 'QueryEditorData2Msg' }
		CommandMsg { 'CommandMsg' }
		GoToLineMsg { 'GoToLineMsg' }
		LogMsg { 'LogMsg' }
		else { 'unlabelled' }
	}
}

// OpStat accumulates what one message type has allocated. bytes is cumulative
// over the session, which is what makes it useful: a type with a modest
// average but a huge total is the one driving the collector.
struct OpStat {
mut:
	count u64
	bytes u64
	peak  u64
}

// MemoryProbe samples the allocator and attributes allocation to the message
// that caused it. It is deliberately a @[heap] struct held by pointer: the
// model is cloned on every update, and the probe's counters have to survive
// that rather than being reset by a struct copy.
//
// It is always sampling. A jump you have to enable instrumentation for is a
// jump you have to reproduce first, and the cost here is two counter reads per
// message plus one syscall every 250ms.
@[heap]
struct MemoryProbe {
	doc_controller  &documents.Controller  = unsafe { nil }
	doc_controller2 &documents.Controller2 = unsafe { nil }
mut:
	// process-level
	rss                u64
	rss_peak           u64
	last_rss_sample_ms i64

	// allocator-level, refreshed every frame
	heap_size       u64
	free_bytes      u64
	unmapped_bytes  u64
	live_bytes      u64
	total_allocated u64
	bytes_since_gc  u64

	// derived from watching the counters move, so they need no GC-specific
	// entry points: a drop in bytes_since_gc is a collection, and a heap
	// bigger than any seen before is the collector taking more from the OS.
	collections    u64
	heap_growths   u64
	heap_size_peak u64

	// per-frame churn
	frames            u64
	frame_churn_total u64
	frame_churn_peak  u64
	last_frame_total  u64

	// set from the render context, for the grid accounting
	grid_width  int
	grid_height int

	// recorded by collect_now
	live_after_collect u64
	forced_collects    u64

	ops map[string]OpStat
}

fn MemoryProbe.new(doc_controller &documents.Controller, doc_controller2 &documents.Controller2) &MemoryProbe {
	mut p := &MemoryProbe{
		doc_controller:  doc_controller
		doc_controller2: doc_controller2
	}
	p.refresh_counters()
	p.last_frame_total = p.total_allocated
	p.sample_rss()
	return p
}

// gc_backend_label names the allocator the binary was built against, because
// every counter below reads zero under `-gc none` and that is worth saying out
// loud rather than rendering a panel full of zeroes.
fn gc_backend_label() string {
	$if gcboehm ? {
		return 'boehm'
	} $else $if vgc ? {
		return 'vgc'
	} $else {
		return 'none (counters unavailable)'
	}
}

// gc_counters_available reports whether this build has a collector to ask.
fn gc_counters_available() bool {
	$if gcboehm ? {
		return true
	} $else $if vgc ? {
		return true
	} $else {
		return false
	}
}

fn (mut p MemoryProbe) refresh_counters() {
	u := gc_heap_usage()
	// counted against the high-water mark rather than the previous sample.
	// Once the collector starts unmapping, the heap oscillates, and counting
	// every up-tick turned a dozen real growths into fifty imagined ones.
	if u64(u.heap_size) > p.heap_size_peak {
		if p.heap_size_peak > 0 {
			p.heap_growths += 1
		}
		p.heap_size_peak = u64(u.heap_size)
	}
	if u64(u.bytes_since_gc) < p.bytes_since_gc {
		p.collections += 1
	}
	p.heap_size = u64(u.heap_size)
	p.free_bytes = u64(u.free_bytes)
	p.unmapped_bytes = u64(u.unmapped_bytes)
	p.bytes_since_gc = u64(u.bytes_since_gc)
	p.total_allocated = u64(u.total_bytes)
	p.live_bytes = u64(gc_memory_use())
}

fn (mut p MemoryProbe) sample_rss() {
	now := time.now().unix_milli()
	if now - p.last_rss_sample_ms < rss_sample_interval_ms {
		return
	}
	p.last_rss_sample_ms = now
	p.rss = runtime.used_memory() or { return }
	if p.rss > p.rss_peak {
		p.rss_peak = p.rss
	}
}

// total_allocated_now reads the allocator's cumulative allocation counter.
// It is monotonic, so differencing it across a call brackets everything that
// call allocated, garbage included - which is the number that explains heap
// growth, as opposed to the live set.
fn (p &MemoryProbe) total_allocated_now() u64 {
	return u64(gc_heap_usage().total_bytes)
}

// record_op attributes the bytes allocated since `before` to a message type.
fn (mut p MemoryProbe) record_op(label string, before u64) {
	after := p.total_allocated_now()
	if after < before {
		return
	}
	delta := after - before
	mut stat := p.ops[label] or { OpStat{} }
	stat.count += 1
	stat.bytes += delta
	if delta > stat.peak {
		stat.peak = delta
	}
	p.ops[label] = stat
}

// collect_now forces a collection and records the live set immediately after.
//
// This is the only way to tell retained bytes from garbage. Boehm computes its
// in-use figure during a collection, so between collections the "live" number
// still counts everything that has not been swept yet - which, for a program
// that allocates per frame, is most of it. A heap that looks 25MiB live can
// turn out to be 5MiB of data and 20MiB of garbage the collector has not had
// reason to sweep.
fn (mut p MemoryProbe) collect_now() {
	gc_collect()
	p.refresh_counters()
	p.live_after_collect = p.live_bytes
	p.forced_collects += 1
}

// sample_frame is called once per rendered frame, after the view has run, so
// the churn figure covers both the update and the render for that frame.
fn (mut p MemoryProbe) sample_frame(grid_width int, grid_height int) {
	p.grid_width = grid_width
	p.grid_height = grid_height
	p.refresh_counters()
	p.sample_rss()
	p.frames += 1
	if p.total_allocated >= p.last_frame_total {
		churn := p.total_allocated - p.last_frame_total
		p.frame_churn_total += churn
		if churn > p.frame_churn_peak {
			p.frame_churn_peak = churn
		}
	}
	p.last_frame_total = p.total_allocated
}

fn (p &MemoryProbe) avg_frame_churn() u64 {
	if p.frames == 0 {
		return 0
	}
	return p.frame_churn_total / p.frames
}

// Accounting is the structural half of the panel: bytes derived by walking the
// live data structures rather than asked of the allocator. Comparing its total
// against the collector's live set is what separates "we are retaining a lot"
// from "we are churning a lot", which the process RSS alone cannot tell you.
struct Accounting {
	docs_v1 documents.Footprint
	docs_v2 documents.Footprint
	grid    u64
	screens u64
	logs    u64
}

fn (a Accounting) total() u64 {
	return a.docs_v1.total() + a.docs_v2.total() + a.grid + a.screens + a.logs
}

// MemoryAccountable is implemented by the screens that retain enough for the
// panel to name. It is a separate, optional interface rather than a method on
// Debuggable so a screen holding nothing interesting does not have to carry a
// stub; the panel asks with an `is` check.
interface MemoryAccountable {
	Debuggable
	footprint_bytes() u64
}

// string_array_footprint sizes an array of strings: its own buffer plus the
// bytes each string points at.
//
// It can over-count, because V strings share their backing buffer when one is
// sliced from another, and this cannot see that. Everything it is used for
// here - file paths from a directory walk, preview lines read from disk - holds
// independently allocated strings, so in practice the figure is right.
fn string_array_footprint(items []string) u64 {
	mut total := u64(items.cap) * u64(sizeof(string))
	for s in items {
		total += u64(s.len)
	}
	return total
}

fn (p &MemoryProbe) accounting(logs []LogMsg, screen Debuggable) Accounting {
	mut log_bytes := u64(0)
	for l in logs {
		log_bytes += u64(l.message.len)
	}
	mut docs_v1 := documents.Footprint{}
	if !isnil(p.doc_controller) {
		docs_v1 = p.doc_controller.footprint()
	}
	mut docs_v2 := documents.Footprint{}
	if !isnil(p.doc_controller2) {
		docs_v2 = p.doc_controller2.footprint()
	}
	mut screen_bytes := u64(0)
	if screen is MemoryAccountable {
		screen_bytes = screen.footprint_bytes()
	}
	return Accounting{
		docs_v1: docs_v1
		docs_v2: docs_v2
		grid:    tea.grid_footprint_bytes(p.grid_width, p.grid_height)
		screens: screen_bytes
		logs:    log_bytes
	}
}

// HotOp is one row of the per-message attribution table.
struct HotOp {
	label string
	stat  OpStat
}

// hot_ops returns the message types that have allocated the most, most first.
fn (p &MemoryProbe) hot_ops() []HotOp {
	mut rows := []HotOp{cap: p.ops.len}
	for label, stat in p.ops {
		rows << HotOp{label, stat}
	}
	rows.sort_with_compare(fn (a &HotOp, b &HotOp) int {
		if a.stat.bytes == b.stat.bytes {
			return 0
		}
		return if a.stat.bytes > b.stat.bytes { -1 } else { 1 }
	})
	return rows
}

// fmt_bytes renders a byte count in the largest unit that keeps it readable.
fn fmt_bytes(n u64) string {
	if n < 1024 {
		return '${n} B'
	}
	units := ['KiB', 'MiB', 'GiB', 'TiB']
	mut v := f64(n) / 1024.0
	mut unit := 0
	for v >= 1024.0 && unit < units.len - 1 {
		v /= 1024.0
		unit += 1
	}
	return '${v:.1f} ${units[unit]}'
}

// mem_value_column is where values start, so labels and numbers line up into
// two readable columns.
const mem_value_column = 34

fn draw_mem_section(mut ctx tea.Context, x int, y int, title string) {
	ctx.set_color(palette.debug_header_color)
	ctx.draw_text(x, y, title)
	ctx.reset_color()
}

fn draw_mem_row(mut ctx tea.Context, x int, y int, label string, value string) {
	ctx.set_color(palette.subtle_text_fg_color)
	ctx.draw_text(x + 2, y, label)
	ctx.reset_color()
	ctx.draw_text(x + mem_value_column, y, value)
}

// render_memory draws the memory panel. It returns nothing useful to the
// caller: the panel is read, not interacted with.
//
// Note that rendering this panel allocates - the byte formatting and the
// sorted hot-op rows are per-frame strings - so the churn figures include the
// panel's own cost while it is open. That is called out on screen rather than
// hidden, since the honest alternative (a second set of counters that exclude
// the panel) measures a program you are not running.
// render_memory_accounting draws the structural breakdown and returns the row
// after it. These figures are derived by walking the live data structures, so
// unlike the collector's they are exact and do not include garbage. The gap
// between their total and what the collector reports in use is the point of
// the section: it is how much of the heap is garbage the sweep has not reached.
fn render_memory_accounting(mut ctx tea.Context, x int, y int, p &MemoryProbe, logs []LogMsg, acc Accounting) int {
	mut row := y
	draw_mem_section(mut ctx, x, row, 'ACCOUNTED BYTES')
	row += 1
	draw_mem_row(mut ctx, x, row, 'documents, v2 (${acc.docs_v2.doc_count})', '${fmt_bytes(acc.docs_v2.total())}  text ${fmt_bytes(acc.docs_v2.text_bytes)} / index ${fmt_bytes(acc.docs_v2.line_index_bytes)} / history ${fmt_bytes(acc.docs_v2.history_bytes)} (${acc.docs_v2.history_groups} groups)')
	row += 1
	draw_mem_row(mut ctx, x, row, 'documents, v1 (${acc.docs_v1.doc_count})', '${fmt_bytes(acc.docs_v1.total())}  text ${fmt_bytes(acc.docs_v1.text_bytes)} / history ${fmt_bytes(acc.docs_v1.history_bytes)} (${acc.docs_v1.history_groups} entries)')
	row += 1
	draw_mem_row(mut ctx, x, row, 'render grid (${p.grid_width}x${p.grid_height})', '${fmt_bytes(acc.grid)}  two buffers of ${u64(p.grid_width) * u64(p.grid_height)} cells')
	row += 1
	draw_mem_row(mut ctx, x, row, 'active screen', fmt_bytes(acc.screens))
	row += 1
	draw_mem_row(mut ctx, x, row, 'debug logs (${logs.len})', fmt_bytes(acc.logs))
	row += 1
	accounted := acc.total()
	draw_mem_row(mut ctx, x, row, 'accounted', fmt_bytes(accounted))
	row += 1
	if !gc_counters_available() {
		row += 1
		return row
	}
	// measured against the forced figure when there is one, because comparing
	// a structural total against a number that includes unswept garbage says
	// nothing
	mut basis := p.live_bytes
	mut basis_label := 'vs in-use at last collection'
	if p.forced_collects > 0 {
		basis = p.live_after_collect
		basis_label = 'vs retained after forced collect'
	}
	mut unaccounted := u64(0)
	if basis > accounted {
		unaccounted = basis - accounted
	}
	draw_mem_row(mut ctx, x, row, 'unaccounted', '${fmt_bytes(unaccounted)}  ${basis_label}')
	row += 2
	return row
}

fn render_memory(mut ctx tea.Context, x int, y int, p &MemoryProbe, logs []LogMsg, screen Debuggable) {
	if isnil(p) {
		ctx.draw_text(x + 2, y, 'memory probe unavailable')
		return
	}
	acc := p.accounting(logs, screen)

	mut row := y
	draw_mem_section(mut ctx, x, row, 'PROCESS')
	row += 1
	draw_mem_row(mut ctx, x, row, 'resident set size', fmt_bytes(p.rss))
	row += 1
	draw_mem_row(mut ctx, x, row, 'peak resident', fmt_bytes(p.rss_peak))
	row += 2

	draw_mem_section(mut ctx, x, row, 'COLLECTOR (${gc_backend_label()})')
	row += 1
	if !gc_counters_available() {
		// every figure below reads zero without a collector, and a column of
		// zeroes invites being read as a measurement
		ctx.set_color(palette.help_fg_color)
		ctx.draw_text(x + 2, row, 'built without a collector, so it has no counters to report.')
		row += 1
		ctx.draw_text(x + 2, row, 'nothing is freed in this build: use it for allocation attribution')
		row += 1
		ctx.draw_text(x + 2, row, 'under a profiler, not to judge footprint.')
		ctx.reset_color()
		row += 2
		render_memory_accounting(mut ctx, x, row, p, logs, acc)
		return
	}
	draw_mem_row(mut ctx, x, row, 'heap reserved', '${fmt_bytes(p.heap_size)}  peak ${fmt_bytes(p.heap_size_peak)}')
	row += 1
	// Boehm computes this during a collection, so between collections it still
	// counts whatever has not been swept. That is why the forced figure below
	// exists, and why this one drifts upward until the next collection.
	draw_mem_row(mut ctx, x, row, 'in use at last collection', fmt_bytes(p.live_bytes))
	row += 1
	if p.forced_collects > 0 {
		draw_mem_row(mut ctx, x, row, 'retained after forced collect', '${fmt_bytes(p.live_after_collect)}  (c pressed ${p.forced_collects}x)')
	} else {
		ctx.set_color(palette.help_fg_color)
		ctx.draw_text(x + 2, row, 'press c to collect and see what is actually retained')
		ctx.reset_color()
	}
	row += 1
	draw_mem_row(mut ctx, x, row, 'free within heap', fmt_bytes(p.free_bytes))
	row += 1
	draw_mem_row(mut ctx, x, row, 'unmapped', fmt_bytes(p.unmapped_bytes))
	row += 1
	draw_mem_row(mut ctx, x, row, 'allocated since start', fmt_bytes(p.total_allocated))
	row += 1
	draw_mem_row(mut ctx, x, row, 'since last collection', fmt_bytes(p.bytes_since_gc))
	row += 1
	draw_mem_row(mut ctx, x, row, 'collections', '${p.collections}')
	row += 1
	draw_mem_row(mut ctx, x, row, 'heap growths', '${p.heap_growths}')
	row += 2

	draw_mem_section(mut ctx, x, row, 'CHURN')
	row += 1
	draw_mem_row(mut ctx, x, row, 'frames sampled', '${p.frames}')
	row += 1
	draw_mem_row(mut ctx, x, row, 'per frame, mean', fmt_bytes(p.avg_frame_churn()))
	row += 1
	draw_mem_row(mut ctx, x, row, 'per frame, peak', fmt_bytes(p.frame_churn_peak))
	row += 2

	row = render_memory_accounting(mut ctx, x, row, p, logs, acc)

	draw_mem_section(mut ctx, x, row, 'ALLOCATION BY MESSAGE')
	row += 1
	rows := p.hot_ops()
	mut shown := 0
	mut other := OpStat{}
	for r in rows {
		if shown < max_hot_ops && row < ctx.window_height() - 3 {
			draw_mem_row(mut ctx, x, row, r.label, '${fmt_bytes(r.stat.bytes)}  over ${r.stat.count} msgs, peak ${fmt_bytes(r.stat.peak)}')
			row += 1
			shown += 1
			continue
		}
		other.count += r.stat.count
		other.bytes += r.stat.bytes
	}
	if other.count > 0 {
		draw_mem_row(mut ctx, x, row, 'other (${rows.len - shown} types)', '${fmt_bytes(other.bytes)}  over ${other.count} msgs')
		row += 1
	}
	if rows.len == 0 {
		draw_mem_row(mut ctx, x, row, 'no messages sampled yet', '')
		row += 1
	}
	row += 1

	ctx.set_color(palette.help_fg_color)
	ctx.draw_text(x + 2, row, "churn figures include this panel's own render cost")
	ctx.reset_color()
}
