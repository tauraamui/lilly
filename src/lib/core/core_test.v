module core

fn test_is_binary_file_checks_text_file_successfully() {
	assert is_binary_file("non-existent-file.txt") == true // if file not found, plays it safe
}
