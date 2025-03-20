// Copyright 2025 The Lilly Editor contributors
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

module clipboard

import os

@[heap]
struct WaylandClipboard {}

fn (mut wclipboard WaylandClipboard) copy(text string) bool {
	mut cmd := os.Command{
		path: 'echo ${text} | wl-copy -n'
	}
	defer { cmd.close() or {} }

	cmd.start() or { panic(err) }

	return cmd.exit_code == 0
}

fn (wclipboard WaylandClipboard) paste() []string {
	mut cmd := os.Command{
		path: 'wl-paste -n'
	}
	defer { cmd.close() or {} }

	cmd.start() or { panic(err) }

	mut out := []string{}
	for {
		out << cmd.read_line()
		if cmd.eof {
			break
		}
	}

	if cmd.exit_code == 0 {
		return out
	}
	return []
}
