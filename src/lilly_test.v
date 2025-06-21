// Copyright 2024 The Lilly Editor.contributors
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
import lib.clipboardv3
import lib.buffer
import lib.ui

@[heap]
struct MockLineReader {
	line_data []string
mut:
	given_path string
}

fn (mut m_line_reader MockLineReader) read_lines(path string) ![]string {
	m_line_reader.given_path = path
	return m_line_reader.line_data
}

fn test_lilly_open_file_loads_into_file_buffer_and_buffer_view_maps() {
	mut clip := clipboardv3.new()
	mut lilly := Lilly{
		clipboard: mut clip
	}

	mut m_line_reader := MockLineReader{
		line_data: ["This is a fake document that doesn't exist on disk anywhere"]
	}

	assert lilly.file_buffers.len == 0
	assert lilly.buffer_views.len == 0

	lilly.open_file_with_reader_at("test-file.txt", ui.CursorPos{}, m_line_reader.read_lines) or { assert false }

	assert m_line_reader.given_path == "test-file.txt"
	assert lilly.file_buffers.len == 1
	assert lilly.buffer_views.len == 1

	file_buff := lilly.file_buffers["test-file.txt"] or { assert false, "failed to find buffer instance for path: test-file.txt" }
	buff_view := lilly.buffer_views[file_buff.uuid]  or { assert false, "failed to find view instance for buffer of uuid: ${file_buff.uuid}" }
	assert lilly.view_port == buff_view
}

fn test_lilly_open_file_loads_into_file_buffer_and_buffer_view_maps_if_done_twice_does_not_create_extra_instances() {
	mut clip := clipboardv3.new()
	mut lilly := Lilly{
		clipboard: mut clip
	}

	mut m_line_reader := MockLineReader{
		line_data: ["This is a fake document that doesn't exist on disk anywhere"]
	}

	assert lilly.file_buffers.len == 0
	assert lilly.buffer_views.len == 0

	lilly.open_file_with_reader_at("test-file.txt", ui.CursorPos{}, m_line_reader.read_lines) or { assert false }

	assert m_line_reader.given_path == "test-file.txt"
	assert lilly.file_buffers.len == 1
	assert lilly.buffer_views.len == 1
	assert lilly.view_port.file_path == "test-file.txt"

	mut file_buff := lilly.file_buffers["test-file.txt"] or { assert false, "failed to find buffer instance for path: test-file.txt" }
	mut buff_view := lilly.buffer_views[file_buff.uuid]  or { assert false, "failed to find view instance for buffer of uuid: ${file_buff.uuid}" }
	assert lilly.view_port == buff_view

	lilly.open_file_with_reader_at("test-file.txt", ui.CursorPos{}, m_line_reader.read_lines) or { assert false }
	assert lilly.file_buffers.len == 1
	assert lilly.buffer_views.len == 1
	assert lilly.view_port.file_path == "test-file.txt"

	file_buff = lilly.file_buffers["test-file.txt"] or { assert false, "failed to find buffer instance for path: test-file.txt" }
	buff_view = lilly.buffer_views[file_buff.uuid]  or { assert false, "failed to find view instance for buffer of uuid: ${file_buff.uuid}" }
	assert lilly.view_port == buff_view
}

struct MockFS {
	files map[string][]string
}

fn (m_fs MockFS) read_lines(path string) ![]string {
	if lines := m_fs.files[path] {
		return lines
	}
	return error("unable to find file: ${path}")
}

fn test_lilly_resolve_matches_across_all_open_file_buffers_only_loaded_file_has_match() {
	mock_fs := MockFS{
		files: { "unopened-file-as-yet.txt": [
			"This file is pretending to be on disk and not open yet.",
			"If we have several lines we can // TODO(tauraamui) [26/02/2025]: finish writing lin.."
		] }
	}

	mut clip := clipboardv3.new()
	mut lilly := Lilly{
		clipboard: clip
		line_reader: mock_fs.read_lines
		is_binary_file: fn (p string) bool { return false }
		resolve_workspace_files: fn () []string {
			return [
				"loaded-test-file.txt",
				"unopened-file-as-yet.txt"
			]
		}
	}

	mut m_line_reader := MockLineReader{
		line_data: [
			"// TODO(tauraamui) [26/02/2025]: become a real boy, I mean file!",
			"This file has been loaded by the user at the time of comment match search!"
		]
	}

	assert lilly.file_buffers.len == 0
	assert lilly.buffer_views.len == 0

	lilly.open_file_with_reader_at("loaded-test-file.txt", ui.CursorPos{}, m_line_reader.read_lines) or { assert false }

	assert m_line_reader.given_path == "loaded-test-file.txt"
	assert lilly.file_buffers.len == 1
	assert lilly.buffer_views.len == 1

	assert lilly.resolve_todo_comments_matches() == [
		buffer.Match{
			contents: "TODO(tauraamui) [26/02/2025]: become a real boy, I mean file!"
			file_path: "loaded-test-file.txt", pos: buffer.Pos{ x: 3, y: 0 }
			keyword_len: 4
		},
		buffer.Match{
			contents: "TODO(tauraamui) [26/02/2025]: finish writing lin.."
			file_path: "unopened-file-as-yet.txt", pos: buffer.Pos{ x: 35, y: 1 }
			keyword_len: 4
		}
	]
}

fn test_lilly_resolve_matches_across_all_files_within_workspace() {
}

fn test_lilly_extract_pos_from_path() {
	mut extracted_path, mut extracted_pos := extract_pos_from_path("fake_file.v")
	assert extracted_path == "fake_file.v"
	assert extracted_pos  == none

	extracted_path, extracted_pos = extract_pos_from_path("fake_file.v:4")
	assert extracted_path == "fake_file.v"
	assert extracted_pos? == ui.CursorPos{ x: 0, y: 4 }

	extracted_path, extracted_pos = extract_pos_from_path("x::::::::.v:55:101")
	assert extracted_path == "x::::::::.v"
	assert extracted_pos? == ui.CursorPos{ x: 101, y: 55 }

	extracted_path, extracted_pos = extract_pos_from_path("fake_file.v:30:10")
	assert extracted_path == "fake_file.v"
	assert extracted_pos? == ui.CursorPos{ x: 10, y: 30 }

	extracted_path, extracted_pos = extract_pos_from_path("fake_file.v::10")
	assert extracted_path == "fake_file.v"
	assert extracted_pos? == ui.CursorPos{ x: 10, y: 0 }

	extracted_path, extracted_pos = extract_pos_from_path("fake_file.v:")
	assert extracted_path == "fake_file.v"
	assert extracted_pos  == none // this should just immediately considered an invalid format

	extracted_path, extracted_pos = extract_pos_from_path("112:95")
	assert extracted_path == "112"
	assert extracted_pos? == ui.CursorPos{ x: 0, y: 95 }

	extracted_path, extracted_pos = extract_pos_from_path("fake_file.v:::")
	assert extracted_path == "fake_file.v"
	assert extracted_pos  == none // this should just immediately considered an invalid format

	extracted_path, extracted_pos = extract_pos_from_path("fake_file.v::::")
	assert extracted_path == "fake_file.v"
	assert extracted_pos  == none // this should just immediately considered an invalid format

	extracted_path, extracted_pos = extract_pos_from_path(":")
	assert extracted_path == ""
	assert extracted_pos  == none // this should just immediately considered an invalid format

	extracted_path, extracted_pos = extract_pos_from_path("::")
	assert extracted_path == ""
	assert extracted_pos  == none // this should just immediately considered an invalid format

	extracted_path, extracted_pos = extract_pos_from_path(":::")
	assert extracted_path == ""
	assert extracted_pos  == none // this should just immediately considered an invalid format
}

fn test_lilly_resolve_inactive_file_buffer_paths() {
	mut clip := clipboardv3.new()
	mut lilly := Lilly{
		clipboard: clip
	}

	mut m_line_reader := MockLineReader{
		line_data: ["This is a fake document that doesn't exist on disk anywhere"]
	}

	assert lilly.file_buffers.len == 0
	assert lilly.buffer_views.len == 0

	lilly.open_file_with_reader_at("test-file.txt", ui.CursorPos{}, m_line_reader.read_lines) or { assert false }

	assert lilly.file_buffers.len == 1
	assert lilly.buffer_views.len == 1

	assert lilly.view_port.file_path == "test-file.txt"

	m_line_reader = MockLineReader{
		line_data: ["This is another fake document that doesn't exist on disk anywhere"]
	}

	lilly.open_file_with_reader_at("different-test-file.txt", ui.CursorPos{}, m_line_reader.read_lines) or { assert false }

	assert lilly.view_port.file_path == "different-test-file.txt"

	assert lilly.resolve_inactive_file_buffer_paths() == ["test-file.txt"]
}

// TODO(tauraamui) [12/02/2025] something is horrendously broken with the below tests, its so bad that its making the
//                              v test suite runner have some kind of stroke for all of the other asserts in this file...
/*
fn test_quit_with_dirty_buffers() {
    mut lilly := Lilly{
        log: log.Log{}
        clipboard: clipboardv3.new()
        use_gap_buffer: true
        inactive_buffer_finder_modal: unsafe { nil }
    }

    // Add a view with a dirty buffer
    mut buff := buffer.Buffer{
        file_path: 'test.txt'
    }
    buff.dirty = true
    lilly.buffers << buff
    lilly.views << open_view(mut lilly.log, workspace.Config{}, '', [], lilly.clipboard, mut &lilly.buffers[0])

    // Attempt to quit should return error
    mut got_expected_error := false
    lilly.quit() or {
    	println(err.msg())
        got_expected_error = err.msg() == "Cannot quit: 1 unsaved buffer(s). Save changes or use :q! to force quit"
        return
    }
    assert got_expected_error
}

fn test_quit_with_clean_buffers() {
    mut lilly := Lilly{
        log: log.Log{}
        clipboard: clipboardv3.new()
        use_gap_buffer: true
    }

    mut buff := buffer.Buffer{
        file_path: 'test.txt'
    }
    lilly.buffers << buff
    lilly.views << open_view(mut lilly.log, workspace.Config{}, '', [], lilly.clipboard, mut &lilly.buffers[0])

    // Clean buffers should allow quit
    lilly.quit()!
}
*/
