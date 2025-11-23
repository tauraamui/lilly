module main

import math
import time
import os
import strings
import lib.files
import tauraamui.bobatea as tea

struct FilePickerModel {
mut:
	width               int
	height              int
	finder              files.Finder
	filtered_files      []string
	start_index         int
	selected_index      int
	query               string
	cursor_pos          int
	cursor_blink_frame  int
	last_filtered_query string
	loading             bool
}

fn (m &FilePickerModel) query_runes() []rune {
	return m.query.runes()
}

fn (m &FilePickerModel) rune_len() int {
	return m.query.runes().len
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

pub struct CursorBlinkMsg {
pub:
	time time.Time
}

pub fn open_file_picker() tea.Msg {
	return OpenDialogMsg{
		model: FilePickerModel{
			finder: files.new_finder()
		}
	}
}

pub fn close_file_picker() tea.Msg {
	return CloseDialogMsg{}
}

pub fn (mut m FilePickerModel) init() ?tea.Cmd {
	m.loading = true

	return tea.batch(tea.emit_resize, load_files(os.getwd()), cursor_blink_cmd())
}

pub fn load_files(root string) tea.Cmd {
	return fn [root] () tea.Msg {
		return LoadFilesMsg{
			root: root
		}
	}
}

pub fn cursor_blink_cmd() tea.Cmd {
	return tea.tick(33 * time.millisecond, fn (t time.Time) tea.Msg {
		return CursorBlinkMsg{
			time: t
		}
	})
}

pub fn filter_files_cmd(query string) tea.Cmd {
	return fn [query] () tea.Msg {
		return FilterFilesMsg{
			query: query
		}
	}
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
	if query.len == 0 {
		return file_paths[..if file_paths.len > max_path_entries {
			max_path_entries
		} else {
			file_paths.len
		}]
	}

	can_use_incremental := last_query.len > 0 && query.len > last_query.len
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

pub struct ClearQueryFieldMsg {}

fn clear_query_field() tea.Msg {
	return ClearQueryFieldMsg{}
}

fn (mut m FilePickerModel) on_cancel() (tea.Model, ?tea.Cmd) {
	cmd := if m.query.len == 0 { close_file_picker } else { clear_query_field }
	return m.clone(), cmd
}

fn (mut m FilePickerModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}

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
								println('Selected: ${selected_file}')
								cmds << close_file_picker
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
						'left', 'ctrl+b' {
							if m.cursor_pos > 0 {
								m.cursor_pos--
							}
						}
						'right', 'ctrl+f' {
							if m.cursor_pos < m.rune_len() {
								m.cursor_pos++
							}
						}
						'home', 'ctrl+a' {
							m.cursor_pos = 0
						}
						'end', 'ctrl+e' {
							m.cursor_pos = m.rune_len()
						}
						'backspace' {
							if m.cursor_pos > 0 {
								runes := m.query_runes()
								m.query = (runes[..m.cursor_pos - 1].string()) +
									(runes[m.cursor_pos..].string())
								m.cursor_pos--
								m.selected_index = 0
								m.start_index = 0
								cmds << filter_files_cmd(m.query)
							}
						}
						'delete', 'ctrl+d' {
							if m.cursor_pos < m.rune_len() {
								runes := m.query_runes()
								m.query = (runes[..m.cursor_pos].string()) + (runes[m.cursor_pos +
									1..].string())
								m.selected_index = 0
								m.start_index = 0
								cmds << filter_files_cmd(m.query)
							}
						}
						else {}
					}
				}
				else {
					input_char := msg.string()
					runes := m.query_runes()
					m.query = (runes[..m.cursor_pos].string()) + input_char +
						(runes[m.cursor_pos..].string())
					m.cursor_pos += input_char.runes().len
					m.selected_index = 0
					m.start_index = 0
					cmds << filter_files_cmd(m.query)
				}
			}
		}
		LoadFilesMsg {
			m.finder.search(msg.root)
			m.filtered_files = filter_file_paths(m.finder.files(), m.query, '', [])
			m.last_filtered_query = m.query
			m.loading = false
		}
		FilterFilesMsg {
			if msg.query == m.query {
				m.filtered_files = filter_file_paths(m.finder.files(), msg.query, m.last_filtered_query,
					m.filtered_files)
				m.last_filtered_query = msg.query
			}
		}
		ClearQueryFieldMsg {
			m.query = ''
			m.cursor_pos = 0
			m.selected_index = 0
			m.start_index = 0
			cmds << filter_files_cmd(m.query)
		}
		tea.ResizedMsg {
			m.width = int(f64(msg.window_width) * 0.8)
			m.height = int(f64(msg.window_height) * 0.8)
		}
		CursorBlinkMsg {
			m.cursor_blink_frame = (m.cursor_blink_frame + 1) % int(frames_per_cycle)
			cmds << cursor_blink_cmd()
		}
		else {}
	}
	return m.clone(), tea.batch_array(cmds)
}

const frames_per_cycle = 50.0

fn calculate_cursor_color(blink_frame int) tea.Color {
	angle := f64(blink_frame) * 2.0 * math.pi / frames_per_cycle
	sine_value := math.sin(angle)
	color_range := 255 - 235
	color_value := 235 + int((sine_value + 1.0) * f64(color_range) / 2.0)
	return tea.Color.ansi(color_value)
}

const selected_file_bg_color = tea.Color.ansi(239)

const file_results_layout = tea.new_layout()
	.border(.normal)
	.border_color(tea.Color.ansi(218))

const file_search_field_layout = tea.new_layout()
	.border(.normal)
	.border_color(tea.Color.ansi(189))

fn render_file_path_line(mut ctx tea.Context, file_path string, width int, height int, is_selected bool) {
	mut prefix := '  '
	if is_selected {
		prefix = '» '
		ctx.set_bg_color(selected_file_bg_color)
	}
	ctx.draw_rect(0, height - 3, width - 2, 1)
	ctx.draw_text(0, height - 3, prefix + file_path.replace(os.getwd(), '.'))
	if is_selected {
		ctx.reset_bg_color()
	}
	ctx.push_offset(tea.Offset{ y: -1 })
}

fn (m FilePickerModel) max_visible_items() int {
	file_results_height := m.height - 4
	max_height := file_results_height - 2
	return if max_height > 0 { max_height } else { 0 }
}

fn (m FilePickerModel) render_file_results_pane(mut r_ctx tea.Context, width int, height int) {
	file_results_layout.size(width, height).render(mut r_ctx, fn [m, width, height] (mut ctx tea.Context) {
		max_width := width - 2
		max_height := height - 2
		ctx.set_clip_area(tea.ClipArea{0, 0, max_width - 1, max_height})
		defer { ctx.clear_clip_area() }
		ctx.draw_rect(0, 0, max_width, max_height)

		if m.loading {
			loading_label := 'Loading files…'
			ctx.draw_text((width / 2) - tea.visible_len(loading_label) / 2, height / 2,
				loading_label)
			return
		}

		max_items := max_height
		list_offset_id := ctx.push_offset(tea.Offset{})
		for i, file_path in clamp_files_list_to_scrolled(m.start_index, max_items, m.filtered_files) {
			is_selected := (i + m.start_index) == m.selected_index
			render_file_path_line(mut ctx, file_path, width, height, is_selected)
		}
		ctx.clear_offsets_from(list_offset_id)
	})
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

fn (m FilePickerModel) render_file_search_input_field(mut r_ctx tea.Context, width int) {
	cursor_pos := m.cursor_pos
	cursor_color := calculate_cursor_color(m.cursor_blink_frame)
	query_runes := m.query_runes()

	file_search_field_layout.size(width, 3).render(mut r_ctx, fn [cursor_pos, cursor_color, width, query_runes] (mut l_ctx tea.Context) {
		l_ctx.set_clip_area(tea.ClipArea{0, 0, width - 3, 1})
		defer { l_ctx.clear_clip_area() }
		l_ctx.draw_rect(0, 0, width - 2, 1)
		l_ctx.draw_text(0, 0, '>')

		input_text_offset := l_ctx.push_offset(tea.Offset{ x: 2 })
		cursor_within_content := cursor_pos < query_runes.len
		for i, r in query_runes {
			r_str := r.str()
			if cursor_within_content && i == cursor_pos {
				l_ctx.set_bg_color(cursor_color)
			}
			l_ctx.draw_text(0, 0, r_str)
			l_ctx.push_offset(tea.Offset{ x: tea.visible_len(r_str) })
			l_ctx.reset_bg_color()
		}

		if !cursor_within_content {
			l_ctx.set_bg_color(cursor_color)
			l_ctx.draw_rect(0, 0, 1, 1)
			l_ctx.reset_bg_color()
		}
		l_ctx.clear_from_offset(input_text_offset)
	})
}

fn (m FilePickerModel) view(mut ctx tea.Context) {
	ten_percent_width := int(f64(ctx.window_width()) * 0.1)
	ten_percent_height := int(f64(ctx.window_height()) * 0.1)

	root_layout_width := int(f64(ctx.window_width()) * 0.8)
	root_layout_height := int(f64(ctx.window_height()) * 0.8)

	id := ctx.push_offset(tea.Offset{
		x: ten_percent_width
		y: ten_percent_height
	})
	defer { ctx.clear_offsets_from(id) }

	ctx.draw_rect(0, 0, root_layout_width, root_layout_height)

	m.render_file_results_pane(mut ctx, root_layout_width, root_layout_height - 4)

	ctx.push_offset(tea.Offset{ y: root_layout_height - 4 })
	m.render_file_search_input_field(mut ctx, root_layout_width)
	ctx.pop_offset()
}

fn (m FilePickerModel) debug_data() DebugData {
	selected_path := if m.filtered_files.len == 0 {
		'<no files>'
	} else {
		m.filtered_files[m.selected_index]
	}
	return DebugData{
		name: 'file_picker data'
		data: {
			'start index':           '${m.start_index}'
			'selected index':        '${m.selected_index}'
			'selected path':         selected_path
			'search query':          if m.query.len == 0 { '<empty>' } else { m.query }
			'filtered files size':   '${m.filtered_files.len}'
			'maximum visible files': '${m.max_visible_items()}'
			'cursor pos':            '${m.cursor_pos}'
			'blink frame':           '${m.cursor_blink_frame}'
		}
	}
}

fn (m FilePickerModel) clone() tea.Model {
	return FilePickerModel{
		...m
	}
}
