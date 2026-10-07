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

import os
import strings
import lib.files
import bobatea as tea
import lib.palette
import lib.petal.theme
import lib.boba

// max_preview_scan_bytes bounds how far one preview read may scan for line
// ends. A line is cut at the pane's width, but the rest of it still has to be
// read past to reach the next line, and a file with no line breaks would
// otherwise be read to its end every time it is selected.
const max_preview_scan_bytes = 1024 * 1024

const preview_read_block_size = 4096

struct FilePickerModel {
	theme theme.Theme
mut:
	width               int
	height              int
	finder              files.Finder
	input_field         boba.InputField
	filtered_files      []string
	start_index         int
	selected_index      int
	cursor_blink_frame  int
	last_filtered_query string
	loading             bool
	cached_cwd          string
	preview_path        string
	// preview_lines holds only what fits in the preview pane: at most
	// the pane's rows of lines, each already sanitized and cut to preview_cols cells
	preview_lines []string
	// preview_ends[i] is the file offset just past preview_lines[i]'s line
	// break, where reading resumes when the pane grows taller
	preview_ends []u64
	preview_cols int
	// preview_cut is set when a line was cut to fit preview_cols, so a wider
	// pane has to read the lines again to show more of them
	preview_cut bool
	// preview_done is set when there is nothing more to read: the end of the
	// file, an unreadable file, or the scan limit
	preview_done bool
}

pub struct OpenDialogMsg {
pub:
	model DebuggableModel
}

pub struct LoadFilesMsg {
	root string
}

pub struct FilterFilesMsg {
pub:
	query string
}

pub struct CloseDialogMsg {}

pub fn open_file_picker(ttheme theme.Theme) tea.Cmd {
	return tea.msg_cmd(OpenDialogMsg{
		model: FilePickerModel{
			theme:  ttheme
			finder: files.new_finder()
		}
	})
}

pub fn close_file_picker() tea.Cmd {
	return tea.msg_cmd(CloseDialogMsg{})
}

pub fn (mut m FilePickerModel) init() tea.Cmd {
	m.loading = true
	m.cached_cwd = os.getwd()
	m.input_field = boba.BorderedInputField.new(m.theme.petal_pink)
	m.input_field.focus()
	mut cmds := []tea.Cmd{}
	cmds << m.input_field.init()
	// appended one at a time rather than as an array literal: the literal's
	// element type is taken from its first entry, so starting it with a plain
	// function would make it an array of functions and store the tea.Cmd that
	// follows as a function pointer.
	cmds << tea.emit_resize()
	cmds << load_files(m.cached_cwd)
	return tea.batch_array(cmds)
}

pub fn load_files(root string) tea.Cmd {
	return tea.msg_cmd(LoadFilesMsg{
		root: root
	})
}

pub fn filter_files_cmd(query string) tea.Cmd {
	return tea.msg_cmd(FilterFilesMsg{
		query: query
	})
}

@[inline]
fn score_value_by_query(query string, value string) f32 {
	return f32(int(strings.dice_coefficient(query, value) * 1000)) / 1000
}

fn fuzzy_match(query string, value string) bool {
	query_lower := query.to_lower()
	value_lower := value.to_lower()
	mut query_idx := 0
	for charr in value_lower {
		if query_idx < query_lower.len && charr == query_lower[query_idx] {
			query_idx++
		}
	}
	return query_idx == query_lower.len
}

struct ScoredFile {
	path  string
	score f32
}

const max_path_entries = 500

fn filter_file_paths(file_paths []string, query string, last_query string, last_results []string) []string {
	if query == '' {
		return file_paths[..if file_paths.len > max_path_entries {
			max_path_entries
		} else {
			file_paths.len
		}]
	}

	can_use_incremental := last_query != '' && query.len > last_query.len
		&& query.starts_with(last_query)
	paths_to_filter := if can_use_incremental && last_results.len > 0 {
		last_results
	} else {
		file_paths
	}

	num_workers := 8
	chunk_size := (paths_to_filter.len + num_workers - 1) / num_workers
	mut threads := []thread []ScoredFile{cap: num_workers}

	for i := 0; i < num_workers; i++ {
		start := i * chunk_size
		if start >= paths_to_filter.len {
			break
		}
		end := if start + chunk_size > paths_to_filter.len {
			paths_to_filter.len
		} else {
			start + chunk_size
		}
		chunk := paths_to_filter[start..end].clone()

		threads << spawn fn (paths []string, q string) []ScoredFile {
			mut results := []ScoredFile{cap: paths.len}
			for path in paths {
				if fuzzy_match(q, path) {
					results << ScoredFile{
						path:  path
						score: score_value_by_query(q, path)
					}
				}
			}
			return results
		}(chunk, query)
	}

	mut all_scored := []ScoredFile{cap: paths_to_filter.len}
	for t in threads {
		all_scored << t.wait()
	}

	all_scored.sort(a.score > b.score)

	return all_scored.map(it.path)
}

// preview_size is the number of rows and cells inside the preview pane's
// border, matching the layout in view
fn (m FilePickerModel) preview_size() (int, int) {
	rows := m.height - 3 - 2
	cols := m.width - m.width / 2 - 2
	return if rows > 0 { rows } else { 0 }, if cols > 0 { cols } else { 0 }
}

// load_preview keeps the preview to what the pane can show. A newly selected
// file is read from its start only as far as the pane's rows; a resize reads
// more lines to fill a taller pane, drops lines and cells a smaller one no
// longer shows, and re-reads lines that were cut when the pane gets wider.
fn (mut m FilePickerModel) load_preview() {
	if m.filtered_files.len == 0 || m.selected_index >= m.filtered_files.len {
		m.reset_preview('')
		return
	}
	rows, cols := m.preview_size()
	m.clamp_or_expand_preview_cols(cols)
	m.clamp_or_expand_preview_rows(rows)
}

fn (mut m FilePickerModel) clamp_or_expand_preview_cols(cols int) {
	selected := m.filtered_files[m.selected_index]
	if m.preview_path != selected || (cols > m.preview_cols && m.preview_cut) {
		m.reset_preview(selected)
		m.preview_cols = cols
		return
	}

	if cols == m.preview_cols {
		return
	}

	if cols > m.preview_cols {
		// nothing was cut, so the lines already read are whole
		m.preview_cols = cols
		return
	}

	mut trimmed := []string{cap: m.preview_lines.len}
	for line in m.preview_lines {
		cut := sanitize_preview_line(line, cols)
		if cut.len < line.len {
			m.preview_cut = true
		}
		trimmed << cut
	}
	m.preview_lines = trimmed
	m.preview_cols = cols
}

fn (mut m FilePickerModel) clamp_or_expand_preview_rows(rows int) {
	if rows == m.preview_lines.len {
		return
	}

	if rows > m.preview_lines.len {
		if !m.preview_done {
			from := if m.preview_ends.len > 0 { m.preview_ends.last() } else { u64(0) }
			read := read_preview_lines(m.preview_path, from, rows - m.preview_lines.len, m.preview_cols)
			m.preview_lines << read.lines
			m.preview_ends << read.ends
			m.preview_cut = m.preview_cut || read.cut
			m.preview_done = read.done
		}
		return
	}

	// cloned so the dropped lines are not kept alive by the shared backing
	m.preview_lines = m.preview_lines[..rows].clone()
	m.preview_ends = m.preview_ends[..rows].clone()
	m.preview_done = false
}

fn (mut m FilePickerModel) reset_preview(path string) {
	m.preview_path = path
	m.preview_lines = []
	m.preview_ends = []
	m.preview_cols = 0
	m.preview_cut = false
	m.preview_done = path.len == 0
}

struct PreviewRead {
mut:
	lines []string
	ends  []u64
	cut   bool
	done  bool
}

// read_preview_lines reads up to max_lines lines of path starting at byte
// offset from, a block at a time, keeping only the first max_cols cells of
// each: the rest of a long line is read past but not stored. Lines come back
// as sanitize_preview_line would make them.
fn read_preview_lines(path string, from u64, max_lines int, max_cols int) PreviewRead {
	mut read := PreviewRead{}
	if max_lines <= 0 {
		return read
	}
	mut f := os.open(path) or {
		read.done = true
		return read
	}
	defer {
		f.close()
	}
	f.seek(i64(from), .start) or {
		read.done = true
		return read
	}
	mut buf := []u8{len: preview_read_block_size}
	mut line := new_preview_line(max_cols)
	mut pos := from
	mut line_start := from
	// a multi-byte rune can straddle two blocks, so its bytes are gathered
	// here until it is whole
	mut pending := []u8{cap: 4}
	mut pending_need := 0
	mut scanned := 0
	for read.lines.len < max_lines {
		if scanned >= max_preview_scan_bytes {
			read.done = true
			break
		}
		n := f.read(mut buf) or { 0 }
		if n <= 0 {
			// os.File signals the end with os.Eof; any other error ends the
			// preview just the same
			if pos > line_start {
				read.cut = read.cut || line.full
				read.lines << line.str()
				read.ends << pos
			}
			read.done = true
			break
		}
		scanned += n
		for i in 0 .. n {
			b := buf[i]
			pos++
			if pending.len > 0 {
				if b & 0xc0 == 0x80 {
					pending << b
					if pending.len == pending_need {
						// the lead byte keeps 7 - need bits, the rest 6 each
						mut r := u32(pending[0]) & (u32(0xff) >> (pending_need + 1))
						for c in pending[1..] {
							r = (r << 6) | u32(c & 0x3f)
						}
						line.add(rune(r))
						pending.clear()
					}
					continue
				}
				// a truncated sequence: keep its lead byte as decode_rune_utf8
				// in the renderer would, then handle b as usual
				line.add(rune(pending[0]))
				pending.clear()
			}
			if b == `\n` {
				read.cut = read.cut || line.full
				read.lines << line.str()
				read.ends << pos
				line_start = pos
				line = new_preview_line(max_cols)
				if read.lines.len == max_lines {
					break
				}
				continue
			}
			if line.full || b < 0x80 {
				line.add(rune(b))
				continue
			}
			need := utf8_char_len(b)
			if need <= 1 {
				line.add(rune(b))
				continue
			}
			pending << b
			pending_need = need
		}
	}
	return read
}

// rune_cells is how many terminal cells r takes. It follows the rule
// bobatea's grid uses to place runes (rune_visual_width, which bobatea does
// not export), since a preview line is only cut in the right place when it is
// measured the same way it will be drawn.
fn rune_cells(r rune) int {
	if r < 0x300 {
		return 1
	}
	if (r >= 0x0300 && r <= 0x036f) || r == 0x200d || (r >= 0xfe00 && r <= 0xfe0f)
		|| (r >= 0xfe20 && r <= 0xfe2f) || (r >= 0x1f3fb && r <= 0x1f3ff)
		|| (r >= 0xe0100 && r <= 0xe01ef) {
		return 0
	}
	if r >= 0x1100 && (r <= 0x115f || r == 0x2329 || r == 0x232a
		|| (r >= 0x2e80 && r <= 0xa4cf && r != 0x303f) || (r >= 0xac00 && r <= 0xd7a3)
		|| (r >= 0xf900 && r <= 0xfaff) || (r >= 0xfe10 && r <= 0xfe19)
		|| (r >= 0xfe30 && r <= 0xfe6f) || (r >= 0xff00 && r <= 0xff60)
		|| (r >= 0xffe0 && r <= 0xffe6) || (r >= 0x1f300 && r <= 0x1f64f)
		|| (r >= 0x1f680 && r <= 0x1f6ff) || (r >= 0x1f900 && r <= 0x1f9ff)
		|| (r >= 0x1fa70 && r <= 0x1faff) || (r >= 0x20000 && r <= 0x3fffd)) {
		return 2
	}
	return 1
}

// PreviewLine builds one line of the preview, keeping only what fits in
// max_cells cells
struct PreviewLine {
	max_cells int
mut:
	sb    strings.Builder
	cells int
	// full is set once something did not fit, so the line was cut
	full bool
}

fn new_preview_line(max_cells int) PreviewLine {
	return PreviewLine{
		max_cells: max_cells
		sb:        strings.new_builder(max_cells)
	}
}

fn (mut p PreviewLine) add(r rune) {
	if p.full {
		return
	}
	if r == `\t` {
		// expanded to spaces, to a 4-space tab stop
		spaces := 4 - (p.cells % 4)
		for _ in 0 .. spaces {
			if p.cells >= p.max_cells {
				p.full = true
				return
			}
			p.sb.write_u8(` `)
			p.cells++
		}
		return
	}
	if r < 32 || r == 127 {
		// control characters are dropped
		return
	}
	width := rune_cells(r)
	if width == 0 {
		// a zero-width rune joins the cell before it, so it is kept with that
		// cell, but only so many: they take no room, and a run of them must not
		// grow the line without bound
		if p.cells > 0 && p.sb.len < p.max_cells * 16 {
			p.sb.write_rune(r)
		}
		return
	}
	// a wide rune that would straddle the last cell is left out rather than
	// half drawn: the renderer's clip only checks a rune's first cell, so its
	// second would be drawn over the pane's border
	if p.cells + width > p.max_cells {
		p.full = true
		return
	}
	p.sb.write_rune(r)
	p.cells += width
}

fn (mut p PreviewLine) str() string {
	return p.sb.str()
}

pub struct ClearQueryFieldMsg {}

fn clear_query_field() tea.Cmd {
	return tea.msg_cmd(ClearQueryFieldMsg{})
}

fn (mut m FilePickerModel) on_cancel() (tea.Model, tea.Cmd) {
	cmd := if m.input_field.rune_len() == 0 { close_file_picker() } else { clear_query_field() }
	return m.clone(), cmd
}

const filter_trigger_special_keys = ['backspace', 'delete']! // fixed size array

fn (mut m FilePickerModel) update(msg tea.Msg) (tea.Model, tea.Cmd) {
	mut cmds := []tea.Cmd{}

	i_field, cmd := m.input_field.update(msg)
	cmds << cmd
	m.input_field = i_field

	match msg {
		tea.KeyMsg {
			match msg.k_type {
				.special {
					match msg.string() {
						'escape' {
							return m.on_cancel()
						}
						'ctrl+c' {
							return m.on_cancel()
						}
						'enter' {
							if m.filtered_files.len > 0 && m.selected_index < m.filtered_files.len {
								selected_file := m.filtered_files[m.selected_index]
								m.input_field.reset()
								cmds << close_file_picker()
								cmds << open_file(selected_file)
							}
						}
						'up', 'ctrl+k' {
							m.selected_index++
							max_visible := m.max_visible_items()
							if max_visible > 0 && m.selected_index >= m.start_index + max_visible {
								m.start_index++
								max_start := m.filtered_files.len - max_visible
								if m.start_index > max_start {
									m.start_index = max_start
								}
							}
							if m.selected_index >= m.filtered_files.len {
								m.selected_index = m.filtered_files.len - 1
							}
						}
						'down', 'ctrl+j' {
							m.selected_index--
							if m.selected_index < m.start_index {
								m.start_index--
								if m.start_index < 0 {
									m.start_index = 0
								}
								m.selected_index = m.start_index
							}
						}
						else {
							if filter_trigger_special_keys.contains(msg.string()) {
								m.selected_index = 0
								m.start_index = 0
								query := m.input_field.value()
								cmds << filter_files_cmd(query)
							}
						}
					}
				}
				else {
					m.selected_index = 0
					m.start_index = 0
					query := m.input_field.value()
					cmds << filter_files_cmd(query)
				}
			}
		}
		LoadFilesMsg {
			query := m.input_field.value()
			m.finder.search(msg.root)
			m.filtered_files = filter_file_paths(m.finder.files(), query, '', [])
			m.last_filtered_query = query
			m.loading = false
		}
		FilterFilesMsg {
			query := m.input_field.value()
			if msg.query == query {
				m.filtered_files = filter_file_paths(m.finder.files(), msg.query,
					m.last_filtered_query, m.filtered_files)
				m.last_filtered_query = msg.query
			}
		}
		ClearQueryFieldMsg {
			m.input_field.reset()
			m.selected_index = 0
			m.start_index = 0
			query := m.input_field.value()
			cmds << filter_files_cmd(query)
		}
		tea.ResizedMsg {
			m.width = msg.window_width
			m.height = msg.window_height
		}
		else {}
	}

	m.load_preview()
	return m.clone(), tea.batch_array(cmds)
}

@[params]
struct RenderFilePathLineParams {
	file_path          string
	row                int
	width              int
	height             int
	is_selected        bool
	selection_bg_color tea.Color
	cwd                string
}

// selected_row_prefix marks the selected row. Unselected rows used to draw two
// spaces in its place, which is indistinguishable from the blank cells the pane
// is already cleared to, so they now draw nothing and the path starts at the
// same column either way.
const selected_row_prefix = '» '

const row_prefix_width = 2

fn render_file_path_line(mut ctx tea.Context, opts RenderFilePathLineParams) {
	// rows fill upwards from the bottom of the pane, which the caller used to
	// express by pushing a -1 offset per row. Deriving y from the row index
	// keeps the offset stack flat: draw_text and draw_rect each resolve a
	// position by summing the whole stack, so a per-row offset charged every
	// cell of every later row for the rows above it.
	y := opts.height - 3 - opts.row
	if opts.is_selected {
		highlight_bg_color := opts.selection_bg_color
		ctx.set_color(palette.fg_color(highlight_bg_color))
		ctx.set_bg_color(highlight_bg_color)
		// the fill is what paints the highlight across the row, so it is only
		// needed for the selected one. Drawing it for every row meant painting
		// a full pane width of blank cells per row per frame, which was the
		// largest remaining source of allocation in the editor.
		ctx.draw_rect(0, y, opts.width - 2, 1)
		ctx.draw_text(0, y, selected_row_prefix)
	}
	ctx.draw_text(row_prefix_width, y, opts.file_path.replace(opts.cwd, '.'))
	if opts.is_selected {
		ctx.reset_color()
		ctx.reset_bg_color()
	}
}

fn (m FilePickerModel) max_visible_items() int {
	file_results_height := m.height - 4
	max_height := file_results_height - 2
	return if max_height > 0 { max_height } else { 0 }
}

fn (m FilePickerModel) render_file_results_pane(mut r_ctx tea.Context, width int, height int, border_color tea.Color) {
	cwd := m.cached_cwd
	// drawn between render_begin and render_end rather than in a callback: a
	// callback would have to capture `m`, and a captured context is pinned for
	// the life of the process, so a pane rendered at the cursor's blink rate
	// would leak one copy of this model per frame
	layout := tea.new_layout().border(.normal).border_color(border_color).size(width, height)
	layout.render_begin(mut r_ctx)
	defer { layout.render_end(mut r_ctx) }
	m.draw_file_results(mut r_ctx, width, height, cwd)
}

fn (m FilePickerModel) draw_file_results(mut ctx tea.Context, width int, height int, cwd string) {
	{
		max_width := width - 2
		max_height := height - 2
		ctx.set_clip_area(tea.ClipArea{0, 0, max_width - 1, max_height})
		defer { ctx.clear_clip_area() }
		ctx.clear_area(0, 0, max_width, max_height)

		if m.loading {
			ctx.set_color(m.theme.subtle_light_grey)
			loading_label := 'Loading files…'
			ctx.draw_text((width / 2) - tea.visible_len(loading_label) / 2, height / 2,
				loading_label)
			ctx.reset_color()
			return
		}

		max_items := max_height
		for i, file_path in clamp_files_list_to_scrolled(m.start_index, max_items, m.filtered_files) {
			is_selected := (i + m.start_index) == m.selected_index
			render_file_path_line(mut ctx,
				file_path:          file_path
				row:                i
				width:              width
				height:             height
				is_selected:        is_selected
				selection_bg_color: m.theme.highlight_bg_color
				cwd:                cwd
			)
		}
	}
}

// sanitize_preview_line cuts line to the runes that fit in max_width cells,
// with tabs expanded to spaces and control characters dropped
fn sanitize_preview_line(line string, max_width int) string {
	mut p := new_preview_line(max_width)
	for r in line.runes() {
		p.add(r)
		if p.full {
			break
		}
	}
	return p.str()
}

fn (m FilePickerModel) render_preview_pane(mut r_ctx tea.Context, width int, height int, border_color tea.Color) {
	preview_lines := m.preview_lines
	// inline for the same reason as the results pane: see draw_file_results
	layout := tea.new_layout().border(.normal).border_color(border_color).size(width, height)
	layout.render_begin(mut r_ctx)
	defer { layout.render_end(mut r_ctx) }
	m.draw_preview(mut r_ctx, preview_lines, width, height)
}

fn (m FilePickerModel) draw_preview(mut ctx tea.Context, preview_lines []string, width int, height int) {
	{
		max_width := width - 2
		max_height := height - 2
		ctx.set_clip_area(tea.ClipArea{0, 0, max_width - 1, max_height})
		defer { ctx.clear_clip_area() }
		ctx.clear_area(0, 0, max_width, max_height)

		if preview_lines.len == 0 {
			ctx.set_color(m.theme.subtle_light_grey)
			no_preview_label := 'No preview'
			ctx.draw_text((width / 2) - tea.visible_len(no_preview_label) / 2, height / 2,
				no_preview_label)
			ctx.reset_color()
			return
		}

		visible_lines := if preview_lines.len > max_height { max_height } else { preview_lines.len }
		for i in 0 .. visible_lines {
			ctx.draw_text(0, i, sanitize_preview_line(preview_lines[i], max_width))
		}
	}
}

fn clamp_files_list_to_scrolled(start int, max_items int, initial_files_list []string) []string {
	if initial_files_list.len == 0 || max_items <= 0 {
		return []
	}

	clamped_start := if start < 0 {
		0
	} else if start >= initial_files_list.len {
		initial_files_list.len - 1
	} else {
		start
	}

	end := if clamped_start + max_items > initial_files_list.len {
		initial_files_list.len
	} else {
		clamped_start + max_items
	}

	if end <= clamped_start {
		return []
	}

	return initial_files_list[clamped_start..end]
}

fn (m FilePickerModel) view(mut ctx tea.Context) {
	if m.width == 0 || m.height == 0 {
		return
	}
	// wipe existing rendered cells "behind" the modal
	ctx.clear_area(0, 0, m.width, m.height)

	max_results_height := m.height - 3
	left_width := m.width / 2
	right_width := m.width - left_width

	m.render_file_results_pane(mut ctx, left_width, max_results_height, m.theme.petal_pink)

	preview_offset_id := ctx.push_offset(tea.Offset{ x: left_width })
	m.render_preview_pane(mut ctx, right_width, max_results_height, m.theme.petal_pink)
	ctx.clear_offsets_from(preview_offset_id)

	ctx.push_offset(tea.Offset{ y: max_results_height })
	m.input_field.view(mut ctx)

	ctx.pop_offset()
}

fn (m FilePickerModel) debug_data() DebugData {
	selected_path := if m.filtered_files.len == 0 {
		'<no files>'
	} else {
		m.filtered_files[m.selected_index]
	}
	query := m.input_field.value()
	return DebugData{
		name: 'file_picker data'
		data: {
			'width':                 '${m.width}'
			'height':                '${m.height}'
			'start index':           '${m.start_index}'
			'selected index':        '${m.selected_index}'
			'selected path':         selected_path
			'search query':          if query.len == 0 { '<empty>' } else { query }
			'filtered files size':   '${m.filtered_files.len}'
			'maximum visible files': '${m.max_visible_items()}'
			'blink frame':           '${m.cursor_blink_frame}'
		}
	}
}

fn (m FilePickerModel) width() int {
	return m.width
}

fn (m FilePickerModel) height() int {
	return m.height
}

fn (m FilePickerModel) clone() tea.Model {
	return FilePickerModel{
		...m
	}
}
