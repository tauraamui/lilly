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

struct Config {
	program     string
	input_spec  string
	output_dir  string
	compare_dir string // if non-empty, compare captured frames against this golden dir
}

fn parse_args(args []string) !Config {
	mut program := ''
	mut input_spec := ''
	mut output_dir := 'xpty_frames'
	mut compare_dir := ''

	mut i := 0
	for i < args.len {
		if args[i] == '--compare' {
			i++
			if i >= args.len {
				return error('--compare requires a directory argument')
			}
			compare_dir = args[i]
		} else if args[i] == '--output-dir' {
			i++
			if i >= args.len {
				return error('--output-dir requires a directory argument')
			}
			output_dir = args[i]
		} else if program.len == 0 {
			program = args[i]
		} else if input_spec.len == 0 {
			input_spec = args[i]
		} else {
			return error('unexpected argument: ${args[i]}')
		}
		i++
	}

	if program.len == 0 || input_spec.len == 0 {
		return error('missing required arguments')
	}

	return Config{
		program:     program
		input_spec:  input_spec
		output_dir:  output_dir
		compare_dir: compare_dir
	}
}

fn print_usage() {
	eprintln('usage: xpty [options] <program> <input-sequence>')
	eprintln('')
	eprintln('  Runs <program> inside a pseudo-terminal, sends <input-sequence>')
	eprintln('  keystroke by keystroke, and captures each rendered frame to disk.')
	eprintln('')
	eprintln('  Options:')
	eprintln('    --output-dir <dir>   Directory to save captured frames (default: xpty_frames)')
	eprintln('    --compare <dir>      Compare captured frames against golden frames in <dir>')
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
	eprintln('  Examples:')
	eprintln("    xpty ./lilly '<wait:2000>;ffedi<enter><wait:1000>}}}}}' ")
	eprintln("    xpty --compare testdata/xpty/scroll-scenario ./lilly '<wait:2000>;ffedi<enter><wait:1000>}}}}}' ")
}

fn main() {
	config := parse_args(os.args[1..]) or {
		eprintln('xpty: ${err}')
		eprintln('')
		print_usage()
		exit(1)
	}

	cols := u16(120)
	rows := u16(40)

	os.mkdir_all(config.output_dir) or {
		eprintln('failed to create output directory: ${err}')
		exit(1)
	}

	eprintln('xpty: starting "${config.program}" in ${cols}x${rows} pty')
	eprintln('xpty: input sequence: ${config.input_spec}')
	eprintln('xpty: frames will be saved to ${config.output_dir}/')
	if config.compare_dir.len > 0 {
		eprintln('xpty: will compare against golden frames in ${config.compare_dir}/')
	}

	master_fd, child_pid := spawn_in_pty(config.program, cols, rows) or {
		eprintln('xpty: failed to spawn: ${err}')
		exit(1)
	}

	// Allow the program to initialize and render its first frame.
	eprintln('xpty: waiting for program to initialize...')
	time.sleep(1500 * time.millisecond)

	// Drain any initial output (startup frames).
	initial_output := drain_pty(master_fd, 200)
	if initial_output.len > 0 {
		save_frame(config.output_dir, 0, initial_output)
		eprintln('xpty: captured initial frame (${initial_output.len} bytes)')
	}

	// Parse and send input tokens one at a time, capturing after each.
	tokens := parse_input(config.input_spec)
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
					save_frame(config.output_dir, frame_num, output)
					eprintln('xpty: captured frame ${frame_num} (${output.len} bytes)')
					frame_num++
				}
			}
			WaitToken {
				eprintln('xpty: [${i + 1}/${tokens.len}] waiting ${token.ms}ms')
				time.sleep(token.ms * time.millisecond)

				output := drain_pty(master_fd, 100)
				if output.len > 0 {
					save_frame(config.output_dir, frame_num, output)
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
		save_frame(config.output_dir, frame_num, final_output)
		eprintln('xpty: captured final frame ${frame_num} (${final_output.len} bytes)')
		frame_num++
	}

	eprintln('xpty: done — ${frame_num} frames captured in ${config.output_dir}/')

	// Send quit signal to the child.
	C.kill(child_pid, C.SIGTERM)
	time.sleep(200 * time.millisecond)
	C.kill(child_pid, C.SIGKILL)

	C.close(master_fd)

	// If comparison was requested, run it now.
	if config.compare_dir.len > 0 {
		exit(compare_frames(config.output_dir, config.compare_dir, frame_num))
	}
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

// compare_frames compares captured .raw frames against golden .raw frames.
// Returns 0 if all frames match, 1 if there are differences.
fn compare_frames(captured_dir string, golden_dir string, captured_count int) int {
	eprintln('')
	eprintln('xpty: comparing captured frames against golden frames in ${golden_dir}/')

	// Collect golden .raw files.
	golden_files := os.glob(os.join_path(golden_dir, 'frame_*.raw')) or {
		eprintln('xpty: ERROR: failed to list golden frames: ${err}')
		return 1
	}

	golden_count := golden_files.len
	if golden_count == 0 {
		eprintln('xpty: ERROR: no golden frames found in ${golden_dir}/')
		eprintln('xpty: hint: run without --compare first to capture golden frames, then copy .raw files to ${golden_dir}/')
		return 1
	}

	if captured_count != golden_count {
		eprintln('xpty: FAIL: frame count mismatch — captured ${captured_count}, golden ${golden_count}')
		return 1
	}

	mut failures := 0
	for i := 0; i < captured_count; i++ {
		name := 'frame_${i:04d}.raw'
		captured_path := os.join_path(captured_dir, name)
		golden_path := os.join_path(golden_dir, name)

		if !os.exists(golden_path) {
			eprintln('xpty: FAIL: ${name} — golden frame missing')
			failures++
			continue
		}

		if !os.exists(captured_path) {
			eprintln('xpty: FAIL: ${name} — captured frame missing')
			failures++
			continue
		}

		captured_data := os.read_bytes(captured_path) or {
			eprintln('xpty: FAIL: ${name} — could not read captured frame: ${err}')
			failures++
			continue
		}

		golden_data := os.read_bytes(golden_path) or {
			eprintln('xpty: FAIL: ${name} — could not read golden frame: ${err}')
			failures++
			continue
		}

		if captured_data == golden_data {
			eprintln('xpty: OK: ${name}')
		} else {
			eprintln('xpty: FAIL: ${name} — differs (captured ${captured_data.len} bytes, golden ${golden_data.len} bytes)')
			// Show first differing byte position for debugging.
			min_len := if captured_data.len < golden_data.len {
				captured_data.len
			} else {
				golden_data.len
			}
			for j := 0; j < min_len; j++ {
				if captured_data[j] != golden_data[j] {
					eprintln('xpty:        first difference at byte ${j}: captured 0x${captured_data[j]:02x}, golden 0x${golden_data[j]:02x}')
					break
				}
			}
			if captured_data.len != golden_data.len {
				eprintln('xpty:        size difference: captured ${captured_data.len}, golden ${golden_data.len}')
			}
			failures++
		}
	}

	eprintln('')
	if failures > 0 {
		eprintln('xpty: FAILED — ${failures}/${captured_count} frames differ')
		return 1
	}
	eprintln('xpty: PASSED — all ${captured_count} frames match')
	return 0
}
