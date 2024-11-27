package main

import (
	"errors"
	"fmt"
)

// GapBuffer is a dynamic buffer that allows efficient insertions and deletions
type GapBuffer struct {
	buffer   []rune
	gapStart int
	gapEnd   int
}

// LineTracker manages line start positions
type LineTracker struct {
	lineStarts []int
	gapStart   int
	gapEnd     int
}

// TextEditor combines character and line buffers
type TextEditor struct {
	charBuffer   GapBuffer
	lineTracker  LineTracker
	cursorLine   int
	cursorColumn int
}

// NewGapBuffer creates a new gap buffer with initial capacity
func NewGapBuffer(initialCapacity int) *GapBuffer {
	buffer := make([]rune, initialCapacity)
	return &GapBuffer{
		buffer:   buffer,
		gapStart: 0,
		gapEnd:   initialCapacity,
	}
}

// moveGap repositions the gap to a new location
func (gb *GapBuffer) moveGap(newGapPos int) {
	if newGapPos == gb.gapStart {
		return
	}

	gapSize := gb.gapEnd - gb.gapStart

	if newGapPos < gb.gapStart {
		// Move gap left
		copy(gb.buffer[newGapPos+gapSize:], gb.buffer[newGapPos:gb.gapStart])
	} else {
		// Move gap right
		copy(gb.buffer[gb.gapStart:], gb.buffer[gb.gapEnd:newGapPos])
	}

	gb.gapStart = newGapPos
	gb.gapEnd = newGapPos + gapSize
}

// insert adds a rune at the current gap position
func (gb *GapBuffer) insert(r rune) {
	// Expand buffer if needed
	if gb.gapStart == gb.gapEnd {
		newBuffer := make([]rune, len(gb.buffer)*2)
		copy(newBuffer, gb.buffer[:gb.gapStart])
		copy(newBuffer[gb.gapEnd*2-gb.gapStart:], gb.buffer[gb.gapEnd:])
		gb.buffer = newBuffer
		gb.gapEnd = gb.gapEnd*2 - gb.gapStart
	}

	gb.buffer[gb.gapStart] = r
	gb.gapStart++
}

// NewLineTracker initializes a line tracker
func NewLineTracker(initialCapacity int) *LineTracker {
	return &LineTracker{
		lineStarts: make([]int, initialCapacity),
		gapStart:   0,
		gapEnd:     initialCapacity,
	}
}

// addLineStart records a new line's starting position
func (lt *LineTracker) addLineStart(pos int) {
	// Expand line starts buffer if needed
	if lt.gapStart == lt.gapEnd {
		newLineStarts := make([]int, len(lt.lineStarts)*2)
		copy(newLineStarts, lt.lineStarts[:lt.gapStart])
		copy(newLineStarts[lt.gapEnd*2-lt.gapStart:], lt.lineStarts[lt.gapEnd:])
		lt.lineStarts = newLineStarts
		lt.gapEnd = lt.gapEnd*2 - lt.gapStart
	}

	lt.lineStarts[lt.gapStart] = pos
	lt.gapStart++
}

// NewTextEditor creates a new text editor
func NewTextEditor() *TextEditor {
	return &TextEditor{
		charBuffer:   *NewGapBuffer(100),
		lineTracker:  *NewLineTracker(10),
		cursorLine:   0,
		cursorColumn: 0,
	}
}

// Insert adds a character to the text editor
func (te *TextEditor) Insert(r rune) {
	te.charBuffer.insert(r)

	// Track line starts for newlines
	if r == '\n' {
		te.lineTracker.addLineStart(te.charBuffer.gapStart)
		te.cursorLine++
		te.cursorColumn = 0
	} else {
		te.cursorColumn++
	}
}

// GetLineStart returns the starting position of a given line
func (te *TextEditor) GetLineStart(lineNumber int) (int, error) {
	if lineNumber < 0 || lineNumber >= te.lineTracker.gapStart {
		return 0, errors.New("invalid line number")
	}
	return te.lineTracker.lineStarts[lineNumber], nil
}

// GetLine retrieves the contents of a specific line
func (te *TextEditor) GetLine(lineNumber int) (string, error) {
	lineStart, err := te.GetLineStart(lineNumber)
	if err != nil {
		return "", err
	}

	// Determine line end (next line's start or buffer end)
	var lineEnd int
	if lineNumber+1 < te.lineTracker.gapStart {
		lineEnd, _ = te.GetLineStart(lineNumber + 1)
	} else {
		lineEnd = te.charBuffer.gapStart + (te.charBuffer.gapEnd - te.charBuffer.gapStart)
	}

	// Extract line content
	lineRunes := te.charBuffer.buffer[lineStart:lineEnd]
	return string(lineRunes), nil
}

// Print the entire buffer contents (for debugging)
func (te *TextEditor) Print() string {
	fullBuffer := make([]rune, len(te.charBuffer.buffer)-(te.charBuffer.gapEnd-te.charBuffer.gapStart))
	copy(fullBuffer, te.charBuffer.buffer[:te.charBuffer.gapStart])
	copy(fullBuffer[te.charBuffer.gapStart:], te.charBuffer.buffer[te.charBuffer.gapEnd:])
	return string(fullBuffer)
}

func main() {
	editor := NewTextEditor()

	// Insert some text
	text := "Hello\nWorld\nGo Programming!"
	for _, r := range text {
		editor.Insert(r)
	}

	// Get line contents
	line, _ := editor.GetLine(1) // Should return "World"
	fmt.Println(line)

	// Print entire buffer
	fmt.Println(editor.Print())
}
