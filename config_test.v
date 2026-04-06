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
}
