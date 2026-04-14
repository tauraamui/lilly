// Copyright 2026 The Lilly Editor contributors
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

import os
import time

// Synchronized Update markers used by bobatea to delimit frames.
// BSU = Begin Synchronized Update, ESU = End Synchronized Update.
const bsu = '\x1bP=1s\x1b\\'
const esu = '\x1bP=2s\x1b\\'

fn main() {
	args := os.args[1..]
	if args.len < 2 {
		eprintln('usage: xpty <program> <input-sequence>')
		eprintln('')
		eprintln('  Runs <program> inside a pseudo-terminal, sends <input-sequence>')
		eprintln('  keystroke by keystroke, and captures each rendered frame to disk.')
		eprintln('')
		eprintln('  Special tokens in <input-sequence>:')
		eprintln('    <enter>  -> carriage return')
		eprintln('    <esc>    -> escape (0x1b)')
		eprintln('    <tab>    -> tab')
		eprintln('    <space>  -> space')
		eprintln('    <bs>     -> backspace')
		eprintln('    <up> <down> <left> <right> -> arrow keys')
		eprintln('    <wait:NNN> -> pause NNN milliseconds before next key')
		eprintln('')
		eprintln('  Example:')
		eprintln("    xpty ./lilly ';ffedi<enter>}}}}'")
		exit(1)
	}

	program := args[0]
	input_spec := args[1]

	cols := u16(120)
	rows := u16(40)

	output_dir := 'xpty_frames'
	os.mkdir_all(output_dir) or {
		eprintln('failed to create output directory: ${err}')
		exit(1)
	}

	eprintln('xpty: starting "${program}" in ${cols}x${rows} pty')
	eprintln('xpty: input sequence: ${input_spec}')
	eprintln('xpty: frames will be saved to ${output_dir}/')

	master_fd, child_pid := spawn_in_pty(program, cols, rows) or {
		eprintln('xpty: failed to spawn: ${err}')
		exit(1)
	}

	// Allow the program to initialize and render its first frame.
	eprintln('xpty: waiting for program to initialize...')
	time.sleep(1500 * time.millisecond)

	// Drain any initial output (startup frames).
	initial_output := drain_pty(master_fd, 200)
	if initial_output.len > 0 {
		save_frame(output_dir, 0, initial_output)
		eprintln('xpty: captured initial frame (${initial_output.len} bytes)')
	}

	// Parse and send input tokens one at a time, capturing after each.
	tokens := parse_input(input_spec)
	eprintln('xpty: parsed ${tokens.len} input tokens')

	mut frame_num := 1
	for i, token in tokens {
		match token {
			InputToken {
				bytes := token.bytes
				eprintln('xpty: [${i + 1}/${tokens.len}] sending: ${token.label}')
				write_to_fd(master_fd, bytes)

				// Give the program time to process the input and render.
				time.sleep(150 * time.millisecond)

				output := drain_pty(master_fd, 100)
				if output.len > 0 {
					save_frame(output_dir, frame_num, output)
					eprintln('xpty: captured frame ${frame_num} (${output.len} bytes)')
					frame_num++
				}
			}
			WaitToken {
				eprintln('xpty: [${i + 1}/${tokens.len}] waiting ${token.ms}ms')
				time.sleep(token.ms * time.millisecond)

				output := drain_pty(master_fd, 100)
				if output.len > 0 {
					save_frame(output_dir, frame_num, output)
					eprintln('xpty: captured frame ${frame_num} (${output.len} bytes)')
					frame_num++
				}
			}
		}
	}

	// Final drain: wait a bit and capture any remaining output.
	time.sleep(500 * time.millisecond)
	final_output := drain_pty(master_fd, 200)
	if final_output.len > 0 {
		save_frame(output_dir, frame_num, final_output)
		eprintln('xpty: captured final frame ${frame_num} (${final_output.len} bytes)')
		frame_num++
	}

	eprintln('xpty: done — ${frame_num} frames captured in ${output_dir}/')

	// Send quit signal to the child.
	C.kill(child_pid, C.SIGTERM)
	time.sleep(200 * time.millisecond)
	C.kill(child_pid, C.SIGKILL)

	C.close(master_fd)
}

fn save_frame(dir string, num int, data []u8) {
	// Save raw bytes (with all ANSI escapes intact).
	raw_path := os.join_path(dir, 'frame_${num:04d}.raw')
	os.write_file_array(raw_path, data) or {
		eprintln('xpty: warning: failed to write ${raw_path}: ${err}')
	}

	// Also save a human-readable hex+ascii dump for easier inspection.
	dump_path := os.join_path(dir, 'frame_${num:04d}.dump')
	os.write_file(dump_path, hex_dump(data)) or {
		eprintln('xpty: warning: failed to write ${dump_path}: ${err}')
	}

	// Save an annotated version that labels ANSI escape sequences.
	annotated_path := os.join_path(dir, 'frame_${num:04d}.ansi.txt')
	os.write_file(annotated_path, annotate_ansi(data)) or {
		eprintln('xpty: warning: failed to write ${annotated_path}: ${err}')
	}
}

fn hex_dump(data []u8) string {
	mut lines := []string{}
	mut i := 0
	for i < data.len {
		mut hex_part := ''
		mut ascii_part := ''
		line_start := i
		for j := 0; j < 16 && i < data.len; j++ {
			b := data[i]
			hex_part += '${b:02x} '
			if b >= 0x20 && b < 0x7f {
				ascii_part += b.ascii_str()
			} else {
				ascii_part += '.'
			}
			i++
		}
		lines << '${line_start:08x}  ${hex_part:-49s} |${ascii_part}|'
	}
	return lines.join('\n')
}

fn annotate_ansi(data []u8) string {
	mut result := []string{}
	mut i := 0
	for i < data.len {
		if data[i] == 0x1b {
			// Start of escape sequence
			seq_start := i
			i++
			if i < data.len {
				match data[i] {
					`[` {
						// CSI sequence: ESC [ ... final_byte
						i++
						for i < data.len && data[i] >= 0x20 && data[i] <= 0x3f {
							i++
						}
						if i < data.len {
							i++ // consume final byte
						}
						seq := data[seq_start..i].bytestr()
						result << '[CSI: ${escape_for_display(seq)}]'
					}
					`P` {
						// DCS sequence (used for synchronized updates)
						i++
						for i < data.len {
							if data[i] == 0x1b && i + 1 < data.len && data[i + 1] == `\\` {
								i += 2
								break
							}
							i++
						}
						seq := data[seq_start..i].bytestr()
						if seq == bsu {
							result << '[BSU: Begin Synchronized Update]'
						} else if seq == esu {
							result << '[ESU: End Synchronized Update]'
						} else {
							result << '[DCS: ${escape_for_display(seq)}]'
						}
					}
					`]` {
						// OSC sequence
						i++
						for i < data.len && data[i] != 0x07 {
							if data[i] == 0x1b && i + 1 < data.len && data[i + 1] == `\\` {
								i += 2
								break
							}
							i++
						}
						if i < data.len && data[i] == 0x07 {
							i++
						}
						seq := data[seq_start..i].bytestr()
						result << '[OSC: ${escape_for_display(seq)}]'
					}
					else {
						result << '[ESC+${data[i]:c}]'
						i++
					}
				}
			}
		} else if data[i] >= 0x20 && data[i] < 0x7f {
			// Printable ASCII - collect a run of them.
			start := i
			for i < data.len && data[i] >= 0x20 && data[i] < 0x7f {
				i++
			}
			result << data[start..i].bytestr()
		} else {
			// Control character
			match data[i] {
				0x0a { result << '[LF]' }
				0x0d { result << '[CR]' }
				0x09 { result << '[TAB]' }
				0x08 { result << '[BS]' }
				0x07 { result << '[BEL]' }
				else { result << '[0x${data[i]:02x}]' }
			}
			i++
		}
	}
	return result.join('')
}

fn escape_for_display(s string) string {
	mut result := ''
	for c in s.bytes() {
		if c == 0x1b {
			result += 'ESC'
		} else if c >= 0x20 && c < 0x7f {
			result += c.ascii_str()
		} else {
			result += '\\x${c:02x}'
		}
	}
	return result
}
