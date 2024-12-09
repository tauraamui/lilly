package main

import (
	"testing"
)

func TestTextEditorBasicInsertion(t *testing.T) {
	editor := NewTextEditor()

	// Insert a simple line
	testText := "Hello, world!"
	for _, r := range testText {
		editor.Insert(r)
	}

	// Verify print output
	if editor.Print() != testText {
		t.Errorf("Expected %q, got %q", testText, editor.Print())
	}
}

func TestTextEditorMultilineInsertion(t *testing.T) {
	editor := NewTextEditor()

	// Insert multiple lines
	testText := "Hello\nWorld\nGo Programming!"
	for _, r := range testText {
		editor.Insert(r)
	}

	// Verify total content
	if editor.Print() != testText {
		t.Errorf("Expected %q, got %q", testText, editor.Print())
	}

	// Verify line tracking
	if editor.cursorLine != 2 {
		t.Errorf("Expected cursor line to be 2, got %d", editor.cursorLine)
	}
}

func TestGetLine(t *testing.T) {
	editor := NewTextEditor()

	// Insert multiple lines
	testText := "Hello\nWorld\nGo Programming!"
	for _, r := range testText {
		editor.Insert(r)
	}

	// Test retrieving specific lines
	testCases := []struct {
		lineNumber int
		expected   string
	}{
		{0, "Hello"},
		{1, "World"},
		{2, "Go Programming!"},
	}

	for _, tc := range testCases {
		line, err := editor.GetLine(tc.lineNumber)
		if err != nil {
			t.Errorf("Unexpected error retrieving line %d: %v", tc.lineNumber, err)
		}
		if line != tc.expected {
			t.Errorf("Expected line %d to be %q, got %q", tc.lineNumber, tc.expected, line)
		}
	}
}

func TestLineStartPositions(t *testing.T) {
	editor := NewTextEditor()

	// Insert multiple lines
	testText := "Hello\nWorld\nGo Programming!"
	for _, r := range testText {
		editor.Insert(r)
	}

	// Check line start positions
	testCases := []struct {
		lineNumber int
		expected   int
	}{
		{0, 0},
		{1, 6},
		{2, 12},
	}

	for _, tc := range testCases {
		lineStart, err := editor.GetLineStart(tc.lineNumber)
		if err != nil {
			t.Errorf("Unexpected error getting line start for line %d: %v", tc.lineNumber, err)
		}
		if lineStart != tc.expected {
			t.Errorf("Expected line %d start at %d, got %d", tc.lineNumber, tc.expected, lineStart)
		}
	}
}

func TestErrorCases(t *testing.T) {
	editor := NewTextEditor()

	// Test retrieving line from empty buffer
	_, err := editor.GetLine(0)
	if err == nil {
		t.Error("Expected error when retrieving line from empty buffer")
	}

	// Test retrieving invalid line number
	_, err = editor.GetLine(1)
	if err == nil {
		t.Error("Expected error when retrieving out-of-bounds line")
	}
}

func TestCursorTracking(t *testing.T) {
	editor := NewTextEditor()

	// Insert text with multiple lines
	testText := "Hello\nWorld\nGo!"
	for _, r := range testText {
		editor.Insert(r)
	}

	// Verify cursor tracking
	testCases := []struct {
		expectedLine   int
		expectedColumn int
	}{
		{0, 5},  // End of first line
		{1, 5},  // End of second line
		{2, 4},  // End of last line
	}

	for i, tc := range testCases {
		if editor.cursorLine != tc.expectedLine {
			t.Errorf("Test case %d: Expected cursor line %d, got %d",
				i, tc.expectedLine, editor.cursorLine)
		}
		// The column check is a bit more complex due to newline characters
		if i < 2 && editor.cursorColumn != tc.expectedColumn {
			t.Errorf("Test case %d: Expected cursor column %d, got %d",
				i, tc.expectedColumn, editor.cursorColumn)
		}
	}
}

func TestBufferExpansion(t *testing.T) {
	editor := NewTextEditor()

	// Insert a lot of text to trigger buffer expansion
	longText := "This is a very long text that will force the buffer to expand. " +
				"We're testing the automatic resizing mechanism of our gap buffer. " +
				"It should handle large inputs without breaking."

	for _, r := range longText {
		editor.Insert(r)
	}

	// Verify the entire text was inserted correctly
	if editor.Print() != longText {
		t.Errorf("Buffer expansion failed. Expected full text to be preserved")
	}
}

func TestUnicodeSupport(t *testing.T) {
	editor := NewTextEditor()

	// Insert text with Unicode characters
	unicodeText := "こんにちは\nWorld\n🌍 Testing Unicode!"
	for _, r := range unicodeText {
		editor.Insert(r)
	}

	// Verify Unicode text preservation
	if editor.Print() != unicodeText {
		t.Errorf("Unicode support failed. Expected %q, got %q",
			unicodeText, editor.Print())
	}

	// Verify line retrieval with Unicode
	line, err := editor.GetLine(0)
	if err != nil {
		t.Errorf("Unexpected error retrieving Unicode line: %v", err)
	}
	if line != "こんにちは" {
		t.Errorf("Expected first line to be %q, got %q", "こんにちは", line)
	}
}
