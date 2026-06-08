module main

import bobatea as tea
import lib.documents
import lib.documents.cursor
import lib.petal.theme
import lib.palette

struct EditorModel2 {
	id             int
	file_path      string
	doc_id         int
	theme          theme.Theme
	doc_controller &documents.Controller2
mut:
	chord          Chord
	viewport_width int
	viewport_height int
	top_line int
	visual_sel_start_col ?u64
	visual_sel_start_line ?u64
}

fn EditorModel2.new(l_theme theme.Theme, doc_id int, doc_controller &documents.Controller2) EditorModel2 {
	return EditorModel2{
		doc_id: doc_id
		theme: l_theme
		doc_controller: doc_controller
	}
}

fn (mut m EditorModel2) init() fn () tea.Msg {
	return tea.emit_resize
}

fn (mut m EditorModel2) update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	if msg is EditorModelKeyMsg {
		match msg.mode {
			.normal {
				return m.normal_mode_update(msg.key_msg)
			}
			.insert {
				return m.insert_mode_update(msg.key_msg)
			}
			.visual {
				return m.visual_mode_update(msg.key_msg)
			}
			else {}
		}
	}

	match msg {
		tea.ResizedMsg {
			m.viewport_width  = msg.window_width // artificially shrunk by parent model EditorWorkspace
			m.viewport_height = msg.window_height
		}
		EditorModelMsg {
			return m.editor_model_update(msg.msg)
		}
		SwitchModeMsg {
			return m.switch_mode_update(msg)
		}
		else {}
	}

	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) editor_model_update(msg tea.Msg) (tea.Model, fn () tea.Msg) {
	match msg {
		QueryEditorDataMsg {
			return m.clone(), editor_data(m.data())
		}
		else {}
	}
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) switch_mode_update(msg SwitchModeMsg) (tea.Model, fn () tea.Msg) {
	match msg.mode {
		.normal {
			if msg.from == .insert || msg.from == .normal {
				m.doc_controller.move_cursor_left(m.doc_id)
			}
		}
		.visual {
			cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)
			m.visual_sel_start_line = cursor_line
			m.visual_sel_start_col = cursor_col
			return m.clone(), tea.noop_cmd
		}
		else {}
	}

	m.visual_sel_start_line = ?u64(none)
	m.visual_sel_start_col = ?u64(none)

	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) normal_mode_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	match msg.k_type {
		.runes {
			if action := m.chord.feed(msg.string()) {
				cmd, switching_mode := m.execute_action_normal(action)
				if !switching_mode {
					m.clamp_cursor_to_line_end()
				}
				m.scroll_to_cursor()
				return m.clone(), cmd
			}
		}
		.special {
			match msg.string() {
				'left' {
					m.doc_controller.move_cursor_left(m.doc_id)
				}
				'down' {
					m.doc_controller.move_cursor_down(m.doc_id)
				}
				'right' {
					m.doc_controller.move_cursor_right(m.doc_id)
				}
				'up' {
					m.doc_controller.move_cursor_up(m.doc_id)
				}
				else {}
			}
		}
	}

	m.clamp_cursor_to_line_end()
	m.scroll_to_cursor()
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) insert_mode_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	match msg.k_type {
		.runes {
			for cr in msg.string().runes_iterator() {
				m.doc_controller.insert_rune(m.doc_id, cr)
			}
		}
		.special {
			match msg.string() {
				'enter' {
					m.doc_controller.insert(m.doc_id, `\n`)
				}
				'ctrl+i' { // TAB
					m.doc_controller.insert(m.doc_id, `\t`)
				}
				'backspace' {
					m.doc_controller.backspace(m.doc_id)
				}
				'delete' {
					m.doc_controller.delete(m.doc_id)
				}
				'left' {
					m.doc_controller.move_cursor_left(m.doc_id)
				}
				'down' {
					m.doc_controller.move_cursor_down(m.doc_id)
				}
				'right' {
					m.doc_controller.move_cursor_right(m.doc_id)
				}
				'up' {
					m.doc_controller.move_cursor_up(m.doc_id)
				}
				else {}
			}
		}
	}
	m.scroll_to_cursor()
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) visual_mode_update(msg tea.KeyMsg) (tea.Model, fn () tea.Msg) {
	match msg.k_type {
		.runes {
			if action := m.chord.feed_visual(msg.string()) {
				cmd, switching_mode := m.execute_action_visual(action)
				if !switching_mode {
					m.clamp_cursor_to_line_end()
				}
				m.scroll_to_cursor()
				return m.clone(), cmd

			}
		}
		.special {
			match msg.string() {
				'escape' {
					return m.clone(), switch_mode(.normal)
				}
				else {}
			}
		}
	}
	m.clamp_cursor_to_line_end()
	m.scroll_to_cursor()
	return m.clone(), tea.noop_cmd
}

fn (mut m EditorModel2) execute_action_normal(action ChordAction) (fn () tea.Msg, bool) {
	count := if action.count == 0 { 1 } else { action.count }

	// mode-bound things that aren't really motions; handled before the
	// shared motion table so they can switch modes / insert text.
	match action.motion {
		'o' {
			m.doc_controller.jump_cursor_to_line_end(m.doc_id)
			prefix := m.doc_controller.resolve_prev_line_whitespace_prefix(m.doc_id)
			m.doc_controller.insert(m.doc_id, `\n`)
			for b in prefix {
				m.doc_controller.insert(m.doc_id, b)
			}
			return switch_mode(.insert), true
		}
		'v' {
			return switch_mode(.visual), true
		}
		'line' {
			cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
			for _ in 0..count {
				// deleting the same line since each line delete will move the
				// next line up, into the delete
				m.doc_controller.delete_line(m.doc_id, cursor_line)
			}
			return tea.noop_cmd, false
		}
		else {}
	}

	if op := action.operator {
		// operator + motion: resolve the motion's range, then apply operator.
		// `dd` arrives here as motion == 'line' (see chords.v) — left as a
		// TODO until a linewise range helper exists on Controller2.
		r := motion_range(m.doc_controller, m.doc_id, action.motion, count) or {
			return tea.noop_cmd, false
		}
		apply_operator(m.doc_controller, m.doc_id, op, r)
		return tea.noop_cmd, false
	}

	apply_motion(m.doc_controller, m.doc_id, action.motion, count)
	return tea.noop_cmd, false
}

fn (mut m EditorModel2) execute_action_visual(action ChordAction) (fn () tea.Msg, bool) {
	count := if action.count == 0 { 1 } else { action.count }

	if op := action.operator {
		// in visual mode the selection IS the range — apply the operator
		// against it immediately and exit back to normal mode.
		r := m.current_visual_range() or { return switch_mode(.normal), true }
		apply_operator(m.doc_controller, m.doc_id, op, r)
		return switch_mode(.normal), true
	}

	// pure motion in visual mode = extend selection. The cursor moves;
	// render_visual_selection derives the highlight from sel_start + cursor.
	apply_motion(m.doc_controller, m.doc_id, action.motion, count)
	return tea.noop_cmd, false
}

fn (m EditorModel2) current_visual_range() ?cursor.Range {
	sel_start_line := m.visual_sel_start_line or { return none }
	sel_start_col := m.visual_sel_start_col or { return none }
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)

	mut start_line, mut start_col := sel_start_line, sel_start_col
	mut end_line, mut end_col := cursor_line, cursor_col
	if cursor_line < sel_start_line
		|| (cursor_line == sel_start_line && cursor_col < sel_start_col) {
		start_line, start_col = cursor_line, cursor_col
		end_line, end_col = sel_start_line, sel_start_col
	}

	return cursor.Range{
		start: cursor.Pos.new(int(start_col), int(start_line))
		end:   cursor.Pos.new(int(end_col), int(end_line))
	}
}

fn (mut m EditorModel2) scroll_to_cursor() {
	cursor_line_u, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	cursor_line := int(cursor_line_u)
	line_count := int(m.doc_controller.line_count(m.doc_id))

	if cursor_line < m.top_line {
		m.top_line = cursor_line
	} else if cursor_line >= m.top_line + m.viewport_height {
		m.top_line = cursor_line - m.viewport_height + 1
	}

	max_top := if line_count > m.viewport_height { line_count - m.viewport_height } else { 0 }
	if m.top_line > max_top {
		m.top_line = max_top
	}
	if m.top_line < 0 {
		m.top_line = 0
	}
}

fn (mut m EditorModel2) clamp_cursor_to_line_end() {
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)
	line_bytes := m.doc_controller.get_line_bytes(m.doc_id, cursor_line) or { return }
	runes := line_bytes.bytestr().runes()
	mut grapheme_count := u64(0)
	mut i := 0
	for i < runes.len {
		i = next_grapheme_rune_index(runes, i)
		grapheme_count += 1
	}
	if grapheme_count == 0 {
		return
	}
	if cursor_col >= grapheme_count {
		m.doc_controller.move_cursor_left(m.doc_id)
	}
}

fn (m EditorModel2) view(mut ctx tea.Context) {
	ctx.set_clip_area(tea.ClipArea{ 0, 0, m.width(), m.height() })
	defer { ctx.clear_clip_area() }

	offset_id := m.render_line_numbers(mut ctx)
	defer { ctx.clear_offsets_from(offset_id) }
	m.render_cursor_line_highlight(mut ctx)
	m.render_visual_selection(mut ctx)
	m.render_cursor_block(mut ctx)
	line_count := int(m.doc_controller.line_count(m.doc_id))
	end := if m.top_line + m.viewport_height < line_count { m.top_line + m.viewport_height } else { line_count }
	for y in m.top_line .. end {
		line_bytes := m.doc_controller.get_line_bytes(m.doc_id, u64(y)) or { []u8{} }
		line_str := line_bytes.bytestr().replace('\t', '    ')
		ctx.draw_text(0, y - m.top_line, line_str)
	}
}

fn (m EditorModel2) render_line_numbers(mut ctx tea.Context) int {
	line_count := int(m.doc_controller.line_count(m.doc_id))
	end := if m.top_line + m.viewport_height < line_count { m.top_line + m.viewport_height } else { line_count }
	max_line_nr := m.top_line + end
	gutter_width := num_digits(max_line_nr) + 1

	offset_id := ctx.push_offset(tea.Offset{ x: gutter_width })

	ctx.set_color(m.theme.syntax_comment)
	for y in m.top_line..end {
		line_nr := '${y + 1}'
		ctx.draw_text(-1 - line_nr.len, y - m.top_line, line_nr)
	}
	ctx.reset_color()

	return offset_id
}

fn (m EditorModel2) render_cursor_line_highlight(mut ctx tea.Context) {
	cursor_line, _ := m.doc_controller.cursor_line_and_x(m.doc_id)
	ctx.set_bg_color(m.theme.cursor_line_bg)
	ctx.draw_rect(0, int(cursor_line) - m.top_line, m.viewport_width, 1)
	ctx.reset_bg_color()
}

fn (m EditorModel2) render_cursor_block(mut ctx tea.Context) {
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)
	visual_x, cursor_width := m.visual_x_and_cluster_width_for(cursor_line, cursor_col)

	default_bg_color := ctx.get_default_bg_color() or { palette.matte_black_bg_color }
	ctx.set_bg_color(palette.fg_color(default_bg_color))
	ctx.set_color(default_bg_color)
	ctx.draw_rect(visual_x, int(cursor_line) - m.top_line, cursor_width, 1)
	ctx.reset_bg_color()
	ctx.reset_color()
}

fn (m EditorModel2) render_visual_selection(mut ctx tea.Context) {
	sel_start_line := m.visual_sel_start_line or { return }
	sel_start_col := m.visual_sel_start_col or { return }
	cursor_line, cursor_col := m.doc_controller.cursor_line_and_x(m.doc_id)

	mut start_line, mut start_col := sel_start_line, sel_start_col
	mut end_line, mut end_col := cursor_line, cursor_col
	if cursor_line < sel_start_line
		|| (cursor_line == sel_start_line && cursor_col < sel_start_col) {
		start_line, start_col = cursor_line, cursor_col
		end_line, end_col = sel_start_line, sel_start_col
	}

	start_visual_x, _ := m.visual_x_and_cluster_width_for(start_line, start_col)
	end_visual_x, end_cluster_width := m.visual_x_and_cluster_width_for(end_line, end_col)

	ctx.set_bg_color(m.theme.highlight_bg_color)
	defer { ctx.reset_bg_color() }

	line_count := int(m.doc_controller.line_count(m.doc_id))
	view_end := if m.top_line + m.viewport_height < line_count {
		m.top_line + m.viewport_height
	} else {
		line_count
	}

	if start_line == end_line {
		screen_y := int(start_line) - m.top_line
		if screen_y >= 0 && screen_y < m.viewport_height {
			ctx.draw_rect(start_visual_x, screen_y, end_visual_x + end_cluster_width - start_visual_x, 1)
		}
		return
	}

	// first line: from start_visual_x to end of viewport
	first_sy := int(start_line) - m.top_line
	if first_sy >= 0 && first_sy < m.viewport_height {
		ctx.draw_rect(start_visual_x, first_sy, m.viewport_width - start_visual_x, 1)
	}
	// middle lines: full width
	for y in int(start_line) + 1 .. int(end_line) {
		if y < m.top_line || y >= view_end {
			continue
		}
		ctx.draw_rect(0, y - m.top_line, m.viewport_width, 1)
	}
	// last line: from 0 to end_visual_x + cluster_width
	last_sy := int(end_line) - m.top_line
	if last_sy >= 0 && last_sy < m.viewport_height {
		ctx.draw_rect(0, last_sy, end_visual_x + end_cluster_width, 1)
	}
}

fn (m EditorModel2) visual_x_and_cluster_width_for(line u64, col u64) (int, int) {
	line_bytes := m.doc_controller.get_line_bytes(m.doc_id, line) or { []u8{} }
	runes := line_bytes.bytestr().runes()
	c := int(col) // logical column == grapheme cluster index

	// grapheme-cluster index -> rune prefix length, so visible-width
	// measurement covers ZWJ sequences and variation selectors as one glyph.
	prefix_end := rune_index_after_graphemes(runes, c)
	prefix := runes[..prefix_end].string().replace('\t', '    ')
	visual_x := utf8_str_visible_length(prefix)

	// width of the cluster at the column (min 1 so the block stays visible)
	cluster_width := if prefix_end < runes.len {
		cluster_end := next_grapheme_rune_index(runes, prefix_end)
		if runes[prefix_end] == `\t` {
			4
		} else {
			w := utf8_str_visible_length(runes[prefix_end..cluster_end].string())
			if w < 1 { 1 } else { w }
		}
	} else {
		1
	}

	return visual_x, cluster_width
}

fn (m EditorModel2) width() int {
	return m.viewport_width
}

fn (m EditorModel2) height() int {
	return m.viewport_height
}

fn (m EditorModel2) data() EditorData {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return EditorData{
		id:        m.id
		file_path: m.file_path

		cursor_row: int(cursor_line)
		cursor_col: int(cursor_x)

		chord_display: m.chord.display()
		
		width: m.viewport_width
		height: m.viewport_height
	}
}

fn (m EditorModel2) debug_data() DebugData {
	cursor_line, cursor_x := m.doc_controller.cursor_line_and_x(m.doc_id)
	return DebugData{
		name: 'active editor data'
		data: {
			'id':         '${m.id}'
			'doc_id':     '${m.doc_id}'
			'cursor_row': '${int(cursor_line)}'
			'cursor_col': '${int(cursor_x)}'
			'width':      '${m.viewport_width}'
			'height':     '${m.viewport_height}'
		}
	}
}

fn (m EditorModel2) clone() tea.Model {
	return EditorModel2{
		...m
	}
}

fn rune_index_after_graphemes(runes []rune, n int) int {
	mut i := 0
	mut count := 0
	for i < runes.len && count < n {
		i = next_grapheme_rune_index(runes, i)
		count += 1
	}
	return i
}

fn next_grapheme_rune_index(runes []rune, start int) int {
	if start >= runes.len {
		return start
	}
	mut i := start + 1
	for i < runes.len {
		r := runes[i]
		if r == rune(0x200D) {
			// ZWJ glues to the following codepoint
			i += 1
			if i < runes.len {
				i += 1
			}
			continue
		}
		if is_rune_extender(r) {
			i += 1
			continue
		}
		break
	}
	return i
}

fn is_rune_extender(r rune) bool {
	if r >= rune(0x0300) && r <= rune(0x036F) {
		return true
	}
	if r >= rune(0xFE00) && r <= rune(0xFE0F) {
		return true
	}
	return false
}

