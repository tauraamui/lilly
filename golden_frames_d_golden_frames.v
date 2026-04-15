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
import tauraamui.bobatea as tea

#include <signal.h>

#flag -I .
#include "golden_snapshot_signal.h"

fn C.golden_snapshot_install_handler()
fn C.golden_snapshot_check_and_clear() bool

struct GoldenFrameState {
mut:
	output_dir string
	frame_num  int
	enabled    bool
}

fn GoldenFrameState.init() GoldenFrameState {
	dir := os.getenv('LILLY_GOLDEN_DIR')
	if dir.len == 0 {
		return GoldenFrameState{}
	}

	os.mkdir_all(dir) or {
		eprintln('golden_frames: failed to create output directory ${dir}: ${err}')
		return GoldenFrameState{}
	}

	C.golden_snapshot_install_handler()

	eprintln('golden_frames: enabled, writing frames to ${dir}/')
	return GoldenFrameState{
		output_dir: dir
		frame_num:  0
		enabled:    true
	}
}

fn (mut state GoldenFrameState) capture(ctx tea.Context) {
	if !state.enabled {
		return
	}

	if !C.golden_snapshot_check_and_clear() {
		return
	}

	text := ctx.screen_text()
	path := os.join_path(state.output_dir, 'frame_${state.frame_num:04d}.txt')
	os.write_file(path, text) or {
		eprintln('golden_frames: failed to write ${path}: ${err}')
		return
	}

	eprintln('golden_frames: captured frame ${state.frame_num}')
	state.frame_num++
}
