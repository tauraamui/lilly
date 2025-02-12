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
import log
import lib.clipboardv2
import lib.buffer
import lib.workspace

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

fn test_lilly_opens_file_loads_into_buffer_and_view() {
	mut clip := clipboardv2.new()
	mut lilly := Lilly{
		clipboard: mut clip
		file_finder_modal: unsafe { nil }
		inactive_buffer_finder_modal: unsafe { nil }
		todo_comments_finder_modal: unsafe { nil }
	}

	mut m_line_reader := MockLineReader{
		line_data: ["This is a fake document that doesn't exist on disk anywhere"]
	}

	assert lilly.views.len == 0
	assert lilly.buffers.len == 0

	lilly.open_file_with_reader("test-file.txt", m_line_reader.read_lines) or { assert false }

	assert m_line_reader.given_path == "test-file.txt"
	assert lilly.views.len   == 1
	assert lilly.buffers.len == 1
}

// TODO(tauraamui) [12/02/2025] something is horrendously broken with the below tests, its so bad that its making the
//                              v test suite runner have some kind of stroke for all of the other asserts in this file...
/*
fn test_quit_with_dirty_buffers() {
    mut lilly := Lilly{
        log: log.Log{}
        clipboard: clipboardv2.new()
        use_gap_buffer: true
        file_finder_modal: unsafe { nil }
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
        clipboard: clipboardv2.new()
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
