module buffers

fn test_data_iterator_basic_contiguous_lines() {
	data := [rune(`a`), `b`, `c`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`, `i`]
	mut iter := LineIterator.new(data)

	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next()  == none
}

fn test_data_iterator_multiple_blank_lines() {
	data := [rune(`a`), `b`, `c`, `\n`, `\n`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`, `i`]
	mut iter := LineIterator.new(data)

	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == []
	assert iter.next()? == []
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next()  == none
}

fn test_data_iterator_leading_and_trailing_single_blank_lines() {
	data := [rune(`\n`), `a`, `b`, `c`, `\n`, `\n`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`, `i`, `\n`]
	mut iter := LineIterator.new(data)

	assert iter.next()? == []
	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == []
	assert iter.next()? == []
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next()  == none
}

fn test_data_iterator_leading_and_trailing_multiple_blank_lines() {
	data := [rune(`\n`), `\n`, `a`, `b`, `c`, `\n`, `\n`, `\n`, `d`, `e`, `f`, `\n`, `g`, `h`, `i`, `\n`, `\n`]
	mut iter := LineIterator.new(data)

	assert iter.next()? == []
	assert iter.next()? == []
	assert iter.next()? == [rune(`a`), `b`, `c`]
	assert iter.next()? == []
	assert iter.next()? == []
	assert iter.next()? == [rune(`d`), `e`, `f`]
	assert iter.next()? == [rune(`g`), `h`, `i`]
	assert iter.next()? == []
	assert iter.next()  == none
}

