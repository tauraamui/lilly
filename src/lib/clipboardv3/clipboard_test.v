// Copyright 2025 The Lilly Edtior contributors
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

module clipboardv3

fn test_clipboard_native_implementation() ! {
	mut clipboard := new()
	clipboard.set_content(ClipboardContent{ data: 'This is copied text!', type: .inline })
	assert clipboard.get_content() or { return error('failed to get contents') } == ClipboardContent{
		data: 'This is copied text!'
		type: .inline
	}
}

fn test_clipboard_native_implementation_sets_type_to_block() ! {
	mut clipboard := new()
	clipboard.set_content(ClipboardContent{ data: 'This is copied text!', type: .block })
	assert clipboard.get_content() or { return error('failed to get contents') } == ClipboardContent{
		data: 'This is copied text!'
		type: .block
	}
}

@[if linux ?]
fn test_linux_clipboard_chooses_proc_to_invoke_depending_on_window_server() {
    mock_get_env_x11 := fn (key string) string {
        return "x11"
    }
    mock_get_env_wayland := fn (key string) string {
        return "wayland"
    }
    assert is_x11(mock_get_env_x11)
    assert is_x11(mock_get_env_wayland) == false
}

@[if darwin ?]
fn test_clipboard_native_implementation_returns_no_content_type_from_plaintext_data() {
	$if darwin {
		C.clipboard_set_plaintext(c'A plain text sentence with no meta data!')
		mut clipboard := new()
		assert clipboard.get_content()! == ClipboardContent{
			data: 'A plain text sentence with no meta data!'
			type: .block
		}
	} $else {
		assert true == true
	}
}
