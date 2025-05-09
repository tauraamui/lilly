#!/usr/bin/env -S v run

import build

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
context.task(
	name: "emoji-grid",
	depends: ["copy-emoji-grid-code"]
	run: fn (self build.Task) ! {
		system("v -g run ./src/emoji_grid.v")
		rm("./src/emoji_grid.v")!
	}
)

context.task(
	name: "immediate-grid",
	depends: ["copy-immediate-grid-code"]
	run: fn (self build.Task) ! {
		system("v -g run ./src/immediate_grid.v")
		rm("./src/immediate_grid.v")!
	}
)

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
	name: "copy-emoji-grid-code",
	run: |self| cp("./experiment/tui_render/emoji_grid.v", "./src/emoji_grid.v")!
)
context.artifact(
	name: "copy-immediate-grid-code",
	run: |self| cp("./experiment/tui_render/immediate_grid.v", "./src/immediate_grid.v")!
)

context.run()

