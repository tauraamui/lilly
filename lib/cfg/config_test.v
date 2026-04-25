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

module cfg

import os
import lib.petal.theme

$if !windows {
	fn test_parse_config_file_each_option_set() {
		path := os.join_path(os.temp_dir(), 'test_lilly.cfg')

		os.write_file(path, '# This is a comment\n\ntheme = light\nleader = ","\n')!

		defer {
			os.rm(path) or {}
		}

		config := parse_config_file(path) or {
			assert false, 'expected parse to succeed but got: ${err}'

			return
		}

		assert config.theme == theme.light_theme
		assert config.leader_key == ','
	}

	fn test_parse_config_file_multiple_set() {
		path := os.join_path(os.temp_dir(), 'test_lilly.cfg')

		os.write_file(path, 'theme = dark\ntheme = light\n')!

		defer {
			os.rm(path) or {}
		}

		config := parse_config_file(path) or {
			assert false, 'expected parse to succeed but got: ${err}'

			return
		}

		// Since it's a top-down parser, it uses the last setting
		assert config.theme == theme.light_theme
	}

	fn test_parse_config_file_theme() {
		path := os.join_path(os.temp_dir(), 'test_lilly.cfg')

		os.write_file(path, 'theme = gibberish\n')!

		defer {
			os.rm(path) or {}
		}

		config := parse_config_file(path) or {
			assert err.msg() == 'unknown theme'

			return
		}

		assert false, 'should not succeed'
	}

	fn test_parse_config_file_leader_key_missing_start_quotes() {
		path := os.join_path(os.temp_dir(), 'test_lilly.cfg')

		os.write_file(path, 'leader = ,"\n')!

		defer {
			os.rm(path) or {}
		}

		config := parse_config_file(path) or {
			assert err.msg() == 'expected " at the start'

			return
		}

		assert false, 'should not succeed'
	}

	fn test_parse_config_file_leader_key_end_quotes() {
		path := os.join_path(os.temp_dir(), 'test_lilly.cfg')

		os.write_file(path, 'leader = ",\n')!

		defer {
			os.rm(path) or {}
		}

		config := parse_config_file(path) or {
			assert err.msg() == 'expected " at the end'

			return
		}

		assert false, 'should not succeed'
	}

	fn test_xdg_config_home_not_set_uses_default() {
		os.unsetenv('XDG_CONFIG_HOME')
		paths := xdg_config_paths()
		expected := os.join_path(os.home_dir(), '.config', 'lilly', 'lilly.cfg')
		assert paths[0] == expected
	}

	fn test_xdg_config_home_absolute_path_is_used() {
		os.setenv('XDG_CONFIG_HOME', '/custom/config', true)
		defer { os.unsetenv('XDG_CONFIG_HOME') }
		paths := xdg_config_paths()
		assert paths[0] == '/custom/config/lilly/lilly.cfg'
	}

	fn test_xdg_config_home_relative_path_is_ignored() {
		os.setenv('XDG_CONFIG_HOME', 'relative/path', true)
		defer { os.unsetenv('XDG_CONFIG_HOME') }
		paths := xdg_config_paths()
		expected := os.join_path(os.home_dir(), '.config', 'lilly', 'lilly.cfg')
		assert paths[0] == expected
	}

	fn test_xdg_config_dirs_not_set_uses_default() {
		os.unsetenv('XDG_CONFIG_DIRS')
		paths := xdg_config_paths()
		assert paths.contains('/etc/xdg/lilly/lilly.cfg')
	}

	fn test_xdg_config_dirs_relative_paths_are_skipped() {
		os.setenv('XDG_CONFIG_DIRS', '/valid/dir:relative/dir:/another/valid', true)
		defer { os.unsetenv('XDG_CONFIG_DIRS') }
		paths := xdg_config_paths()
		assert paths.contains('/valid/dir/lilly/lilly.cfg')
		assert paths.contains('/another/valid/lilly/lilly.cfg')
		assert !paths.any(it.contains('relative/dir'))
	}

	fn test_local_path_comes_before_system_paths() {
		os.unsetenv('XDG_CONFIG_HOME')
		os.unsetenv('XDG_CONFIG_DIRS')
		paths := xdg_config_paths()
		local := os.join_path(os.home_dir(), '.config', 'lilly', 'lilly.cfg')
		system := '/etc/xdg/lilly/lilly.cfg'
		assert paths.index(local) < paths.index(system)
	}

	fn test_config_loads_from_xdg_config_home() {
		tmp_dir := os.temp_dir()
		cfg_dir := os.join_path(tmp_dir, 'lilly_test_config')
		cfg_path := os.join_path(cfg_dir, 'lilly', 'lilly.cfg')
		os.mkdir_all(os.dir(cfg_path)) or { assert false, 'failed to create directories' }
		os.write_file(cfg_path, '# This is a comment\n\ntheme = light\nleader = ","\n') or {
			assert false, 'failed to write config file'
		}
		defer {
			os.rmdir_all(cfg_dir) or {} // not really an issue, test is exiting anyway
			os.unsetenv('XDG_CONFIG_HOME')
		}

		os.setenv('XDG_CONFIG_HOME', cfg_dir, true)
		config := Config.new()
		assert config.leader_key == ','
	}
}
