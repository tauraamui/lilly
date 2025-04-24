#!/usr/bin/env -S v run

import build
import io

const app_name = "lilly"

mut context := build.context(
	default: "run"
)

// BUILD TASKS
context.task(name: "build", depends: ["generate-git-hash"], run: |self| system("v ./src -o lilly"))
context.task(name: "build-prod", depends: ["generate-git-hash"], run: |self| system("v ./src -o ${app_name}"))
context.task(name: "run", depends: ["generate-git-hash"], run: |self| system("v -g run ./src ."))
context.task(name: "run-with-gap", depends: ["generate-git-hash"], run: |self| system("v -g run ./src -ugb ."))
context.task(name: "run-debug-log", depends: ["generate-git-hash"], run: |self| system("v -g run ./src --log-level debug ."))
context.task(name: "run-gui", depends: ["generate-git-hash"], run: |self| system("v -g -d gui run ./src ."))

// TEST TASKS
context.task(name: "test", run: |self| system("v -g test ./src"))
context.task(name: "verbose-test", run: |self| system("v -g -stats test ./src"))

// EXPERIMENTS
context.task(name: "emoji-grid", depends: ["copy-emoji-set"], run: |self| system("v -g run ./experiment/tui_render"))

// UTIL TASKS
context.task(name: "git-prune", run: |self| system("git remote prune origin"))
context.task(
	name: "apply-license-header",
	help: "executes addlicense tool to insert license headers into files without one",
	run: |self| system("addlicense -v -c \"The Lilly Edtior contributors\" -y \"2025\" ./src/*")
)
context.task(
	name: "install-license-tool",
	help: "REQUIRES GO: installs a tool used to insert the license header into source files",
	run: |self| system("go install github.com/google/addlicense@latest")
)

// ARTIFACTS
context.artifact(
	name: "generate-git-hash",
	help: "generate .githash to contain latest commit of current branch to embed in builds",
	run: |self| system("git log -n 1 --pretty=format:\"%h\" | tee ./src/.githash")
)
context.artifact(
	name: "copy-emoji-set",
	help: "copies the emoji map set from lib into experiment dir",
	run: fn (self build.Task) ! {
		src_emoji_set_path := "./src/lib/utf8/emoji_test_set.v"
		dst_emoji_set_path := "./experiment/tui_render/emoji_test_set.v"

		mut src_emoji_set_file := open_file(src_emoji_set_path, "r") or { panic("failed to open ${src_emoji_set_path} for reading -> ${err}") }
		defer { src_emoji_set_file.close() }

		mut dst_emoji_set_file := open_file(dst_emoji_set_path, "w") or { panic("failed to open ${dst_emoji_set_path} for appending -> ${err}") }
		defer { dst_emoji_set_file.close() }

		mut buf_line_reader := io.new_buffered_reader(reader: src_emoji_set_file)

		mut line_num := 0
		for {
			cur_line_num := line_num
			line_num += 1

			source_file_line := buf_line_reader.read_line() or {
				assert err is io.Eof
				break
			}

			if cur_line_num == 0 {
				dst_emoji_set_file.writeln("module main")!
				continue
			}

			dst_emoji_set_file.writeln(source_file_line)!
		}
	}
)

context.run()

