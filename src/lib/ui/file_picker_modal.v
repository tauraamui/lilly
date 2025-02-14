module ui

@[noinit]
pub struct FilePickerModal {
	file_paths []string
mut:
	open bool
}

pub fn FilePickerModal.new(file_paths []string) FilePickerModal {
	return FilePickerModal{
		file_paths: file_paths
	}
}

pub fn (mut f_picker FilePickerModal) open() {
	f_picker.open = true
}

pub fn (f_picker FilePickerModal) is_open() bool { return f_picker.open }

pub fn (mut f_picker FilePickerModal) close() {
	f_picker.open = false
}

