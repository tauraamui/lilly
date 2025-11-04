module main

import os
import tauraamui.bobatea as tea

struct FilePickerModel {
mut:
	width          int
	height         int
	files          []string
	filtered_files []string
	selected_index int
	query          string
	loading        bool
	needs_loading  bool
}

struct OpenDialogMsg {
	model tea.Model
}

struct LoadFilesMsg {}

struct CloseDialogMsg {}

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
	m.needs_loading = true
	return tea.emit_resize
}

fn load_files_cmd() tea.Cmd {
	return fn () tea.Msg {
		return LoadFilesMsg{}
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

fn (mut m FilePickerModel) update(msg tea.Msg) (tea.Model, ?tea.Cmd) {
	match msg {
		tea.KeyMsg {
			match msg.string() {
				'escape' {
					return FilePickerModel{}, close_file_picker
				}
				'ctrl+c' {
					return FilePickerModel{}, close_file_picker
				}
				'enter' {
					if m.filtered_files.len > 0 && m.selected_index < m.filtered_files.len {
						// TODO: Open selected file
						selected_file := m.filtered_files[m.selected_index]
						println('Selected: ${selected_file}')
						return FilePickerModel{}, close_file_picker
					}
				}
				'up', 'ctrl+k' {
					if m.selected_index > 0 {
						m.selected_index--
					}
				}
				'down', 'ctrl+j' {
					if m.selected_index < m.filtered_files.len - 1 {
						m.selected_index++
					}
				}
				'backspace' {
					if m.query.len > 0 {
						m.query = m.query[..m.query.len - 1]
						m.filtered_files = filter_files(m.files, m.query)
						m.selected_index = 0
					}
				}
				else {
					// Add character to query
					if msg.string().len == 1 && msg.string().is_ascii() {
						m.query += msg.string()
						m.filtered_files = filter_files(m.files, m.query)
						m.selected_index = 0
					}
				}
			}
		}
		LoadFilesMsg {
			m.files = find_files_efficiently()
			m.filtered_files = filter_files(m.files, m.query)
			m.loading = false
		}
		tea.ResizedMsg {
			m.width = int(f64(msg.window_width) * 0.8)
			m.height = int(f64(msg.window_height) * 0.8)
			// Trigger file loading after first resize
			if m.needs_loading {
				m.needs_loading = false
				return m.clone(), load_files_cmd()
			}
		}
		else {}
	}
	return m.clone(), none
}

const root_layout = tea.new_layout()
	.border(.normal)
	.border_color(tea.Color.ansi(236))

fn (m FilePickerModel) render_file_results_pane(mut ctx tea.Context) {
	if m.loading {
		ctx.draw_text(1, 4, 'Loading files...')
		return
	}

	// File list
	start_y := 4
	max_items := m.height - 6

	for i, file in m.filtered_files {
		if i >= max_items {
			break
		}

		y := start_y + i
		if i == m.selected_index {
			// Highlight selected item
			ctx.draw_text(1, y, '> ${file}')
		} else {
			ctx.draw_text(3, y, file)
		}
	}

	// Status line
	if m.filtered_files.len > 0 {
		status := '${m.filtered_files.len} files'
		ctx.draw_text(1, m.height - 2, status)
	} else if !m.loading {
		ctx.draw_text(1, m.height - 2, 'No files found')
	}
}

fn (m FilePickerModel) view(mut ctx tea.Context) {
	id := ctx.push_offset(tea.Offset{
		x: int(f64(ctx.window_width()) * 0.1)
		y: int(f64(ctx.window_height()) * 0.1)
	})
	defer { ctx.clear_offsets_from(id) }

	root_layout.size(m.width, m.height).render(mut ctx, fn [m] (mut ctx tea.Context) {
		ctx.set_clip_area(tea.ClipArea{0, 0, m.width - 3, m.height - 3})
		defer { ctx.clear_clip_area() }
		ctx.draw_rect(0, 0, m.width, m.height)


		// Title
		title := 'Find Files'
		ctx.draw_text((m.width - title.len) / 2, 0, title)

		m.render_file_results_pane(mut ctx)

		/*
		// Query input
		query_prompt := '> ${m.query}'
		ctx.draw_text(1, 2, query_prompt)

		if m.loading {
			ctx.draw_text(1, 4, 'Loading files...')
			return
		}

		// File list
		start_y := 4
		max_items := m.height - 6

		for i, file in m.filtered_files {
			if i >= max_items {
				break
			}

			y := start_y + i
			if i == m.selected_index {
				// Highlight selected item
				ctx.draw_text(1, y, '> ${file}')
			} else {
				ctx.draw_text(3, y, file)
			}
		}

		// Status line
		if m.filtered_files.len > 0 {
			status := '${m.filtered_files.len} files'
			ctx.draw_text(1, m.height - 2, status)
		} else if !m.loading {
			ctx.draw_text(1, m.height - 2, 'No files found')
		}
		*/
	})
}

fn (m FilePickerModel) clone() tea.Model {
	return FilePickerModel{
		...m
	}
}
