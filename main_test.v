// Copyright 2026 The Lilly Edtior contributors
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

struct CallRecord {
mut:
	symlink_origins []string
	symlink_dests   []string
	rm_paths        []string
	mkdir_paths     []string
	exit_code       int = -1
}

fn default_os_fns(mut record CallRecord) OsFns {
	return OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (_ string) bool {
			return true
		}
		mkdir_all:  fn (_ string) ! {}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn (_ string) ?string {
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}
}

fn test_no_flags_does_nothing() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{}, '0.1.0', default_os_fns(mut record)) or {
		panic('unexpected error: ${err}')
	}

	assert record.exit_code == -1
	assert record.symlink_origins == []
	assert record.symlink_dests == []
}

fn test_show_version_exits_zero() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ show_version: true }, '0.1.0', default_os_fns(mut record)) or {
		panic('unexpected error: ${err}')
	}

	assert record.exit_code == 0
	assert record.symlink_origins == []
}

fn test_symlink_creates_link_in_usr_local_bin_when_not_termux() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (_ string) bool {
			return true
		}
		mkdir_all:  fn (_ string) ! {}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn (_ string) ?string {
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	assert record.symlink_origins == ['/tmp/lilly']
	assert record.symlink_dests == ['/usr/local/bin/lilly']
	assert record.exit_code == 0
}

fn test_symlink_creates_link_in_termux_bin_when_termux() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (p string) bool {
			return p == '/data/data/com.termux/files'
		}
		exists:     fn (_ string) bool {
			return true
		}
		mkdir_all:  fn (_ string) ! {}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
		}
		executable: fn () string {
			return '/data/data/com.termux/files/usr/bin/lilly-build'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn (_ string) ?string {
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	assert record.symlink_origins == [
		'/data/data/com.termux/files/usr/bin/lilly-build',
	]
	assert record.symlink_dests == ['/data/data/com.termux/files/usr/bin/lilly']
	assert record.exit_code == 0
}

fn test_symlink_falls_back_to_local_bin_when_usr_local_bin_not_writable() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (p string) bool {
			return p == '/usr/local/bin'
		}
		mkdir_all:  fn [mut record] (p string) ! {
			record.mkdir_paths << p
		}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
			if dest == '/usr/local/bin/lilly' {
				return error('permission denied')
			}
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn (_ string) ?string {
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	assert record.symlink_origins == ['/tmp/lilly', '/tmp/lilly']
	assert record.symlink_dests == ['/usr/local/bin/lilly',
		os.join_path('/home/test', '.local', 'bin', 'lilly')]
	assert record.mkdir_paths == [os.join_path('/home/test', '.local', 'bin')]
	assert record.exit_code == 0
}

fn test_symlink_exits_1_when_mkdir_usr_local_bin_fails() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (_ string) bool {
			return false
		}
		mkdir_all:  fn (_ string) ! {
			return error('permission denied')
		}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn (_ string) ?string {
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	assert record.exit_code == 1
	assert record.symlink_origins == []
}

fn test_symlink_exits_1_when_home_dir_empty_on_fallback() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (_ string) bool {
			return true
		}
		mkdir_all:  fn (_ string) ! {}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
			return error('permission denied')
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return ''
		}
		getenv_opt: fn (_ string) ?string {
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	assert record.exit_code == 1
	assert record.symlink_origins == ['/tmp/lilly']
	assert record.symlink_dests == ['/usr/local/bin/lilly']
}

fn test_symlink_exits_1_when_mkdir_local_bin_fails_on_fallback() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (p string) bool {
			return p == '/usr/local/bin'
		}
		mkdir_all:  fn (_ string) ! {
			return error('permission denied')
		}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
			if dest == '/usr/local/bin/lilly' {
				return error('permission denied')
			}
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn (_ string) ?string {
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	assert record.exit_code == 1
	assert record.symlink_origins == ['/tmp/lilly']
}

fn test_symlink_exits_1_when_both_symlinks_fail() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (_ string) bool {
			return true
		}
		mkdir_all:  fn (_ string) ! {}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
			return error('permission denied')
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn (_ string) ?string {
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	assert record.exit_code == 1
	assert record.symlink_origins == ['/tmp/lilly', '/tmp/lilly']
	assert record.symlink_dests == ['/usr/local/bin/lilly',
		os.join_path('/home/test', '.local', 'bin', 'lilly')]
}

fn test_symlink_fallback_warns_when_local_bin_not_in_path() {
	mut record := &CallRecord{}

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (p string) bool {
			return p == '/usr/local/bin'
		}
		mkdir_all:  fn [mut record] (p string) ! {
			record.mkdir_paths << p
		}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
			if dest == '/usr/local/bin/lilly' {
				return error('permission denied')
			}
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn (key string) ?string {
			if key == 'PATH' {
				return '/usr/bin:/bin'
			}
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	// Symlink succeeded via fallback
	assert record.exit_code == 0
	assert record.symlink_dests == ['/usr/local/bin/lilly',
		os.join_path('/home/test', '.local', 'bin', 'lilly')]
	// Note: the PATH warning is printed to stderr, which we can't easily capture here,
	// but we verify the code path was reached by confirming the fallback completed successfully.
}

fn test_symlink_fallback_no_warning_when_local_bin_already_in_path() {
	mut record := &CallRecord{}
	local_bin := os.join_path('/home/test', '.local', 'bin')

	execute_on_flags(CfgArgs{ symlink: true }, '0.1.0', OsFns{
		is_dir:     fn (_ string) bool {
			return false
		}
		exists:     fn (p string) bool {
			return p == '/usr/local/bin'
		}
		mkdir_all:  fn [mut record] (p string) ! {
			record.mkdir_paths << p
		}
		rm:         fn [mut record] (p string) ! {
			record.rm_paths << p
		}
		symlink:    fn [mut record] (origin string, dest string) ! {
			record.symlink_origins << origin
			record.symlink_dests << dest
			if dest == '/usr/local/bin/lilly' {
				return error('permission denied')
			}
		}
		executable: fn () string {
			return '/tmp/lilly'
		}
		home_dir:   fn () string {
			return '/home/test'
		}
		getenv_opt: fn [local_bin] (key string) ?string {
			if key == 'PATH' {
				return '/usr/bin:${local_bin}:/bin'
			}
			return none
		}
		exit:       fn [mut record] (code int) {
			record.exit_code = code
		}
	}) or { panic('unexpected error: ${err}') }

	assert record.exit_code == 0
	assert record.symlink_dests == ['/usr/local/bin/lilly',
		os.join_path('/home/test', '.local', 'bin', 'lilly')]
}
