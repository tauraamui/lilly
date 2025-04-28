module draw

struct Grid {
	data []Cell
}

struct Cell {
	x     int
	y     int
	data  ?rune
	width int
}

fn Grid.new(width int, height int) Grid {
}

