module buffers

fn test_data_iterator_basic_contiguous_lines() {
	data := [rune(`a`), `b`, `c`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`, `i`]
	mut iter := LineIterator.new(data)

	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next()  == none
}

