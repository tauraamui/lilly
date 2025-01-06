module main
import log
import lib.clipboardv2
import lib.buffer
import lib.workspace

fn test_quit_with_dirty_buffers() {
    mut editor := Editor{
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
    editor.buffers << buff
    editor.views << open_view(mut editor.log, workspace.Config{}, '', [], editor.clipboard, mut &editor.buffers[0])

    // Attempt to quit should return error
    mut got_expected_error := false
    editor.quit() or {
        got_expected_error = err.msg() == "Cannot quit: 1 unsaved buffer(s). Save changes or use :q! to force quit"
        return
    }
    assert got_expected_error
}

fn test_quit_with_clean_buffers() {
    mut editor := Editor{
        log: log.Log{}
        clipboard: clipboardv2.new()
        use_gap_buffer: true
    }

    mut buff := buffer.Buffer{
        file_path: 'test.txt'
    }
    editor.buffers << buff
    editor.views << open_view(mut editor.log, workspace.Config{}, '', [], editor.clipboard, mut &editor.buffers[0])

    // Clean buffers should allow quit
    editor.quit()!
}
