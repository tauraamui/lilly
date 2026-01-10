module main

import math
import os
import strings
import lib.files
import tauraamui.bobatea as tea
import palette
import theme
import boba

struct FilePickerModel {
	theme               theme.Theme
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
	return fn [ttheme] () tea.Msg {
		return OpenDialogMsg{
			model: FilePickerModel{
				theme: ttheme
				finder: files.new_finder()
			}
		}
	}
}

pub fn close_file_picker() tea.Msg {
	return CloseDialogMsg{}
}

pub fn (mut m FilePickerModel) init() ?tea.Cmd {
	m.loading = true
	m.input_field = boba.BorderedInputField.new()
	m.input_field.focus()
	mut cmds := []tea.Cmd{}
	if input_init_cmd := m.input_field.init() {
		cmds << input_init_cmd
	}
	cmds << [tea.emit_resize, load_files(os.getwd())]
	// return tea.batch(tea.emit_resize, input_init_cmd, load_files(os.getwd()))
	return tea.batch_array(cmds)
}

pub fn load_files(root string) tea.Cmd {
	return fn [root] () tea.Msg {
		return LoadFilesMsg{
			root: root
		}
	}
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
	cmd := if m.input_field.rune_len() == 0 { close_file_picker } else { clear_query_field }
	return m.clone(), cmd
}

const filter_trigger_special_keys = ["backspace", "delete"]

fn (mut m FilePickerModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	mut cmds := []tea.Cmd{}

	i_field, cmd := m.input_field.update(msg)
	u_cmd := cmd or { tea.noop_cmd }
	cmds << u_cmd
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
								cmds << close_file_picker
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
				m.filtered_files = filter_file_paths(m.finder.files(), msg.query, m.last_filtered_query,
					m.filtered_files)
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

@[params]
struct RenderFilePathLineParams {
	file_path          string
	width              int
	height             int
	is_selected        bool
	selection_bg_color tea.Color
}

fn render_file_path_line(
	mut ctx tea.Context, opts RenderFilePathLineParams
) {
	mut prefix := '  '
	if opts.is_selected {
		prefix = '» '
		selected_path_highlight_bg_color := opts.selection_bg_color
		ctx.set_color(palette.fg_color(selected_path_highlight_bg_color))
		ctx.set_bg_color(selected_path_highlight_bg_color)
	}
	ctx.draw_rect(0, opts.height - 3, opts.width - 2, 1)
	ctx.draw_text(0, opts.height - 3, prefix + opts.file_path.replace(os.getwd(), '.'))
	if opts.is_selected {
		ctx.reset_color()
		ctx.reset_bg_color()
	}
	ctx.push_offset(tea.Offset{ y: -1 })
}

fn (m FilePickerModel) max_visible_items() int {
	file_results_height := m.height - 4
	max_height := file_results_height - 2
	return if max_height > 0 { max_height } else { 0 }
}

const subtle_bordered_layout = tea.new_layout()
	.border(.normal)
	.border_color(palette.subtle_border_fg_color)

fn (m FilePickerModel) render_file_results_pane(mut r_ctx tea.Context, width int, height int) {
	subtle_bordered_layout.size(width, height).render(mut r_ctx, fn [m, width, height] (mut ctx tea.Context) {
		max_width := width - 2
		max_height := height - 2
		ctx.set_clip_area(tea.ClipArea{0, 0, max_width - 1, max_height})
		defer { ctx.clear_clip_area() }
		ctx.draw_rect(0, 0, max_width, max_height)

		if m.loading {
			ctx.set_color(m.theme.subtle_light_grey)
			loading_label := 'Loading files…'
			ctx.draw_text((width / 2) - tea.visible_len(loading_label) / 2, height / 2,
				loading_label)
			ctx.reset_color()
			return
		}

		max_items := max_height
		list_offset_id := ctx.push_offset(tea.Offset{})
		for i, file_path in clamp_files_list_to_scrolled(m.start_index, max_items, m.filtered_files) {
			is_selected := (i + m.start_index) == m.selected_index
			render_file_path_line(mut ctx, file_path: file_path, width: width, height: height, is_selected: is_selected, selection_bg_color: m.theme.highlight_bg_color)
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
	if m.width == 0 || m.height == 0 { return }
	// wipe existing rendered cells "behind" the modal
	ctx.draw_rect(0, 0, m.width, m.height)

	max_results_height := m.height - 3
	m.render_file_results_pane(mut ctx, m.width, max_results_height)

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

fn (m FilePickerModel) width() int { return m.width }

fn (m FilePickerModel) height() int { return m.height }

fn (m FilePickerModel) clone() tea.Model {
	return FilePickerModel{
		...m
	}
}
