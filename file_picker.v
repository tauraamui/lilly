module main

import math
import time
import os
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
		return LoadFilesMsg{ root: root }
	}
}

pub fn cursor_blink_cmd() tea.Cmd {
	// Blink every ~33ms for smooth animation (30 FPS)
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

fn filter_file_paths(file_paths []string, query string) []string {
	if query.len == 0 {
		return file_paths[..if file_paths.len > 100 {
			100
		} else {
			file_paths.len
		}]
	}

	mut filtered := []string{}
	for file in file_paths {
		if file.to_lower().contains(query.to_lower()) {
			filtered << file
			if filtered.len >= 100 {
				break
			}
		}
	}
	return filtered
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
								// TODO: Open selected file
								selected_file := m.filtered_files[m.selected_index]
								println('Selected: ${selected_file}')
								// return FilePickerModel{}, close_file_picker
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
								if m.start_index < 0 { m.start_index = 0 }
								m.selected_index = m.start_index
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
								m.start_index = 0
								cmds << filter_files_cmd(m.query)
								// return m.clone(), filter_files_cmd(m.query)
							}
						}
						'delete', 'ctrl+d' {
							if m.cursor_pos < m.query.len {
								m.query = m.query[..m.cursor_pos] + m.query[m.cursor_pos + 1..]
								m.selected_index = 0
								m.start_index = 0
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
					m.start_index = 0
					cmds << filter_files_cmd(m.query)
				}
			}
		}
		LoadFilesMsg {
			m.finder.search(msg.root)
			m.filtered_files = filter_file_paths(m.finder.files(), m.query)
			m.last_filtered_query = m.query
			m.loading = false
		}
		FilterFilesMsg {
			// only update if this is the most recent query
			if msg.query == m.query {
				m.filtered_files = filter_file_paths(m.finder.files(), msg.query)
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
	}
	ctx.draw_rect(0, height - 3, width - 2, 1)
	ctx.draw_text(0, height - 3, prefix + file_path.replace(os.getwd(), "."))
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
		max_width  :=  width - 2
		max_height := height - 2
		ctx.draw_rect(0, 0, max_width, max_height) // force clear cells behind modal

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
			'start index':    '${m.start_index}'
			'selected index': '${m.selected_index}'
			'selected path':  selected_path
			'search query':   if m.query.len == 0 { '<empty>' } else { m.query }
			'filtered files size': '${m.filtered_files.len}'
			'maximum visible files': '${m.max_visible_items()}'
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
