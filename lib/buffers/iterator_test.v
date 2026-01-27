module buffers

fn test_data_iterator() {
	data := [rune(`a`), `b`, `c`, `\n`, `d`, `e`, `f`]
	mut iter := LineIterator.new(data)

	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == [rune(`d`), `e`, `f`]
}

