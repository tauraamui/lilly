module main

import os

fn find_files() []string {
	$if darwin {
		return macos_find_files()
	}
	// Use external tools for efficient file discovery, similar to telescope
	// Priority: rg > fd > find
	if os.exists_in_system_path('rg') {
		result := os.execute('rg --files --color never')
		if result.exit_code == 0 {
			return result.output.split_into_lines().filter(it.len > 0)
		}
	}

	if os.exists_in_system_path('fd') {
		result := os.execute('fd --type f --color never')
		if result.exit_code == 0 {
			return result.output.split_into_lines().filter(it.len > 0)
		}
	}

	// Fallback to basic find command
	result := os.execute('find . -type f')
	if result.exit_code == 0 {
		return result.output.split_into_lines().filter(it.len > 0)
	}

	return []
}

fn macos_find_files() []string {
	return []
}

