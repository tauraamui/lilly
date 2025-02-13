module ui

@[noinit]
pub struct FilePickerModal {
mut:
	open bool
}

pub fn FilePickerModal.new(file_paths []string) FilePickerModal {
	return FilePickerModal{}
}

pub fn (mut f_picker FilePickerModal) open() {
	f_picker.open = true
}

pub fn (mut f_picker FilePickerModal) close() {
	f_picker.open = false
}

