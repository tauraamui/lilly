// Copyright 2024 The Lilly Editor contributors
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

fn wd_resolver() string {
	return 'test-workspace'
}

fn test_resolve_file_and_workspace_dir_paths() {
	assert resolve_options_from_args([]).log_level == log.Level.disabled
	mut file_path, mut workspace_path := resolve_file_and_workspace_dir_paths([], wd_resolver)!
	assert file_path == ''
	assert workspace_path == 'test-workspace'

	file_path, workspace_path = resolve_file_and_workspace_dir_paths([
		'./random-dir/test-file.txt',
	], wd_resolver)!
	assert file_path == './random-dir/test-file.txt'
	assert workspace_path == './random-dir'
}

fn test_resolve_file_and_workspace_dir_paths_with_args() {
	mock_args := ['--log-level', 'debug', '.']

	assert resolve_options_from_args(mock_args).log_level == log.Level.debug

	mut file_path, mut workspace_path := resolve_file_and_workspace_dir_paths(mock_args,
		wd_resolver)!
	assert file_path == ''
	assert workspace_path == '.'

	file_path, workspace_path = resolve_file_and_workspace_dir_paths([
		'./random-dir/test-file.txt',
	], wd_resolver)!
	assert file_path == './random-dir/test-file.txt'
	assert workspace_path == './random-dir'
}

fn test_resolve_options_from_args_no_show_version_flag() {
	mock_args := []string{}
	assert resolve_options_from_args(mock_args).show_version == false
}

fn test_resolve_options_from_args_show_version_long_flag() {
	mock_args := ['--version']
	assert resolve_options_from_args(mock_args).show_version
}

fn test_resolve_options_from_args_show_version_short_flag() {
	mock_args := ['-v']
	assert resolve_options_from_args(mock_args).show_version
}

fn test_resolve_options_from_args_no_show_help_flag() {
	mock_args := []string{}
	assert resolve_options_from_args(mock_args).show_help == false
}

fn test_resolve_options_from_args_show_help_long_flag() {
	mock_args := ['--help']
	assert resolve_options_from_args(mock_args).show_help
}

fn test_resolve_options_from_args_show_help_short_flag() {
	mock_args := ['-h']
	assert resolve_options_from_args(mock_args).show_help
}

fn test_resolve_options_from_args_no_debug_mode_flag() {
	mock_args := []string{}
	assert resolve_options_from_args(mock_args).debug_mode == false
}

fn test_resolve_options_from_args_debug_mode_long_flag() {
	mock_args := ['--debug']
	assert resolve_options_from_args(mock_args).debug_mode
}

fn test_resolve_options_from_args_debug_mode_short_flag() {
	mock_args := ['-d']
	assert resolve_options_from_args(mock_args).debug_mode
}

fn test_resolve_options_from_args_no_capture_panics_flag() {
	mock_args := []string{}
	assert resolve_options_from_args(mock_args).capture_panics == false
}

fn test_resolve_options_from_args_capture_panics_long_flag() {
	mock_args := ['--capture-panics']
	assert resolve_options_from_args(mock_args).capture_panics == true
}

fn test_resolve_options_from_args_capture_panics_short_flag() {
	mock_args := ['-cp']
	assert resolve_options_from_args(mock_args).capture_panics == true
}

fn test_resolve_options_from_args_no_disable_capture_panics_flag() {
	mock_args := []string{}
	assert resolve_options_from_args(mock_args).capture_panics == false
}

fn test_resolve_options_from_args_disable_capture_panics_long_flag() {
	mock_args := ['--disable-capture-panics']
	assert resolve_options_from_args(mock_args).capture_panics == false
}

fn test_resolve_options_from_args_disable_capture_panics_short_flag() {
	mock_args := ['-dpc']
	assert resolve_options_from_args(mock_args).capture_panics == false
}

fn test_resolve_options_from_args_no_log_level_label_long_flag() {
	mock_args := []string{}
	assert resolve_options_from_args(mock_args).log_level == log.Level.disabled
}

fn test_resolve_options_from_args_log_level_label_long_flag() {
	mock_args := ['--log-level', 'debug']
	assert resolve_options_from_args(mock_args).log_level == log.Level.debug
}

fn test_resolve_options_from_args_log_level_label_short_flag() {
	mock_args := ['-ll', 'warn']
	assert resolve_options_from_args(mock_args).log_level == log.Level.warn
}

fn test_resolve_options_from_args_log_level_label_short_flag_with_invalid_level() {
	mock_args := ['-ll', 'smoked-sausage']
	assert resolve_options_from_args(mock_args).log_level == log.Level.disabled
}
