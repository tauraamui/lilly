// Copyright 2024 The Lilly lilly.contributors
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
