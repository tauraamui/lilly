module main

import os
import math
import time
import tauraamui.bobatea as tea

struct FilePickerModel {
mut:
	width               int
	height              int
	files               []string
	filtered_files      []string
	selected_index      int
	query               string
	cursor_pos          int
	cursor_blink_frame  int
	last_filtered_query string
	loading             bool
}

struct OpenDialogMsg {
	model DebuggableModel
}

struct LoadFilesMsg {}

struct FilterFilesMsg {
	query string
}

struct CloseDialogMsg {}

struct CursorBlinkMsg {
	time time.Time
}

fn open_file_picker() tea.Msg {
	return OpenDialogMsg{
		model: FilePickerModel{}
	}
}

fn close_file_picker() tea.Msg {
	return CloseDialogMsg{}
}

fn (mut m FilePickerModel) init() ?tea.Cmd {
	m.loading = true

	return tea.batch(tea.emit_resize, load_files, cursor_blink_cmd())
}

fn load_files() tea.Msg {
	return LoadFilesMsg{}
}

fn cursor_blink_cmd() tea.Cmd {
	// Blink every ~33ms for smooth animation (30 FPS)
	return tea.tick(33 * time.millisecond, fn (t time.Time) tea.Msg {
		return CursorBlinkMsg{
			time: t
		}
	})
}

fn filter_files_cmd(query string) tea.Cmd {
	return fn [query] () tea.Msg {
		return FilterFilesMsg{
			query: query
		}
	}
}

fn find_files_efficiently() []string {
	// Use external tools for efficient file discovery, similar to telescope
	// Priority: rg > fd > find
	if os.exists_in_system_path('rg') {
		result := os.execute('rg --files --color never')
		if result.exit_code == 0 {
			return result.output.split_into_lines().filter(it.len > 0)
		}
	}

	if os.exists_in_system_path('fd') {
		result := os.execute('fd --type f --color never')
		if result.exit_code == 0 {
			return result.output.split_into_lines().filter(it.len > 0)
		}
	}

	// Fallback to basic find command
	result := os.execute('find . -type f')
	if result.exit_code == 0 {
		return result.output.split_into_lines().filter(it.len > 0)
	}

	return []
}

fn filter_files(files []string, query string) []string {
	if query.len == 0 {
		return files[..if files.len > 100 {
			100
		} else {
			files.len
		}]
	}

	mut filtered := []string{}
	for file in files {
		if file.to_lower().contains(query.to_lower()) {
			filtered << file
			if filtered.len >= 100 {
				break
			}
		}
	}
	return filtered
}

struct ClearQueryFieldMsg {}

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
								// TODO: Open selected file
								selected_file := m.filtered_files[m.selected_index]
								println('Selected: ${selected_file}')
								// return FilePickerModel{}, close_file_picker
								cmds << close_file_picker
							}
						}
						'up', 'ctrl+k' {
							if m.selected_index < m.filtered_files.len - 1 {
								m.selected_index++
							}
						}
						'down', 'ctrl+j' {
							if m.selected_index > 0 {
								m.selected_index--
							}
						}
						'left', 'ctrl+b' {
							if m.cursor_pos > 0 {
								m.cursor_pos--
							}
						}
						'right', 'ctrl+f' {
							if m.cursor_pos < m.query.len {
								m.cursor_pos++
							}
						}
						'home', 'ctrl+a' {
							m.cursor_pos = 0
						}
						'end', 'ctrl+e' {
							m.cursor_pos = m.query.len
						}
						'backspace' {
							if m.cursor_pos > 0 {
								m.query = m.query[..m.cursor_pos - 1] + m.query[m.cursor_pos..]
								m.cursor_pos--
								m.selected_index = 0
								cmds << filter_files_cmd(m.query)
								// return m.clone(), filter_files_cmd(m.query)
							}
						}
						'delete', 'ctrl+d' {
							if m.cursor_pos < m.query.len {
								m.query = m.query[..m.cursor_pos] + m.query[m.cursor_pos + 1..]
								m.selected_index = 0
								cmds << filter_files_cmd(m.query)
								// return m.clone(), filter_files_cmd(m.query)
							}
						}
						else {}
					}
				}
				else {
					input_char := msg.string()
					m.query = m.query[..m.cursor_pos] + input_char + m.query[m.cursor_pos..]
					m.cursor_pos += input_char.len
					m.selected_index = 0
					cmds << filter_files_cmd(m.query)
				}
			}
		}
		LoadFilesMsg {
			m.files = find_files_efficiently()
			m.filtered_files = filter_files(m.files, m.query)
			m.last_filtered_query = m.query
			m.loading = false
		}
		FilterFilesMsg {
			// only update if this is the most recent query
			if msg.query == m.query {
				m.filtered_files = filter_files(m.files, msg.query)
				m.last_filtered_query = msg.query
			}
		}
		ClearQueryFieldMsg {
			m.query = ''
			m.cursor_pos = 0
			m.selected_index = 0
			cmds << filter_files_cmd(m.query)
		}
		tea.ResizedMsg {
			m.width = int(f64(msg.window_width) * 0.8)
			m.height = int(f64(msg.window_height) * 0.8)
		}
		CursorBlinkMsg {
			// update cursor blink frame and schedule next blink
			m.cursor_blink_frame = (m.cursor_blink_frame + 1) % int(frames_per_cycle)
			cmds << cursor_blink_cmd()
		}
		else {}
	}
	return m.clone(), tea.batch_array(cmds)
}

const frames_per_cycle = 50.0

fn calculate_cursor_color(blink_frame int) tea.Color {
	// Create a smooth sine wave animation between 235 (darkest) and 255 (brightest)
	// blink_frame cycles from 0 to 839 (840 frames total for 40% slower animation)

	// Convert frame to radians (0 to 2π)
	angle := f64(blink_frame) * 2.0 * math.pi / frames_per_cycle

	// Use sine wave to oscillate between -1 and 1
	sine_value := math.sin(angle)

	// Map sine wave (-1 to 1) to color range (235 to 255)
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
		ctx.draw_rect(0, height - 3, width, 1)
		defer { ctx.reset_bg_color() }
	}
	ctx.draw_text(0, height - 3, prefix + file_path)
	ctx.push_offset(tea.Offset{ y: -1 })
}

fn (m FilePickerModel) render_file_results_pane(mut r_ctx tea.Context, width int, height int) {
	file_results_layout.size(width, height).render(mut r_ctx, fn [m, width, height] (mut ctx tea.Context) {
		ctx.set_clip_area(tea.ClipArea{0, 0, width - 3, height - 2})
		defer { ctx.clear_clip_area() }

		ctx.draw_rect(0, 0, width - 2, height - 2) // force clear cells behind modal

		if m.loading {
			loading_label := 'Loading files…'
			ctx.draw_text((width / 2) - tea.visible_len(loading_label) / 2, height / 2,
				loading_label)
			return
		}

		max_items := height - 2
		display_count := if m.filtered_files.len > max_items {
			max_items
		} else {
			m.filtered_files.len
		}
		list_offset_id := ctx.push_offset(tea.Offset{})
		for i in 0 .. display_count {
			file_index := i
			file_path := m.filtered_files[file_index]
			is_selected := file_index == m.selected_index
			render_file_path_line(mut ctx, file_path, width, height, is_selected)
		}
		ctx.clear_offsets_from(list_offset_id)
	})
}

fn (m FilePickerModel) view(mut ctx tea.Context) {
	ten_percent_width := int(f64(ctx.window_width()) * 0.1)
	ten_percent_height := int(f64(ctx.window_height()) * 0.1)
	root_layout_width := m.width
	root_layout_height := m.height

	id := ctx.push_offset(tea.Offset{
		x: ten_percent_width
		y: ten_percent_height
	})
	defer { ctx.clear_offsets_from(id) }

	m.render_file_results_pane(mut ctx, root_layout_width, root_layout_height - 4)
	ctx.push_offset(tea.Offset{ y: root_layout_height - 4 })
	query := m.query
	cursor_pos := m.cursor_pos
	cursor_color := calculate_cursor_color(m.cursor_blink_frame)
	file_search_field_layout.size(root_layout_width, 3).render(mut ctx, fn [query, cursor_pos, cursor_color, root_layout_width] (mut l_ctx tea.Context) {
		l_ctx.set_clip_area(tea.ClipArea{0, 0, root_layout_width - 3, 1})
		defer { l_ctx.clear_clip_area() }
		l_ctx.draw_rect(0, 0, root_layout_width - 2, 1) // force clear cells behind
		l_ctx.draw_text(0, 0, '>')
		l_ctx.draw_text(2, 0, query)

		// Draw animated cursor
		cursor_x := 2 + cursor_pos
		if cursor_x < root_layout_width - 3 {
			l_ctx.set_bg_color(cursor_color)
			l_ctx.draw_rect(cursor_x, 0, 1, 1)
			l_ctx.reset_bg_color()
		}
	})
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
			'selected index': '${m.selected_index}'
			'selected path':  selected_path
			'search query':   if m.query.len == 0 { '<empty>' } else { m.query }
			'cursor pos':     '${m.cursor_pos}'
			'blink frame':    '${m.cursor_blink_frame}'
		}
	}
}

fn (m FilePickerModel) clone() tea.Model {
	return FilePickerModel{
		...m
	}
}
