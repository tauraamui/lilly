module cfg

import lib.petal.theme

pub const light_theme_name = theme.light_theme_name
pub const dark_theme_name = theme.dark_theme_name

pub struct Config {
pub:
	theme      theme.Theme
	leader_key string
}

@[params]
pub struct ConfigOptions {
pub:
	load_from_path ?string = '~/.config/petal/petal.cfg'
}

pub fn Config.new(opts ConfigOptions) Config {
	if path_to_load := opts.load_from_path {
		assert path_to_load.len > 0
		// do some loading from file here
		// return Config{}
	}

	return Config{
		theme:      theme.dark_theme
		leader_key: ';'
	}
}

pub fn (c Config) set_theme(name string) Config {
	return Config{
		...c
		theme: if name == 'dark' { theme.dark_theme } else { theme.light_theme }
	}
}
