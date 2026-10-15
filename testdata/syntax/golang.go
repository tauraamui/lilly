// Go syntax stress file. Lexing only.
package main

import (
	"context"
	"errors"
	"fmt"
	str "strings"
)

/*
Block comment spanning lines.
/* Go block comments do NOT nest, so this line is still the same comment
and this */ ends it: from here on is code, including the stray close */
var afterComment = 1 /* inline */ + 2

const (
	KB = 1 << (10 * (iota + 1))
	MB
	GB
)

var (
	hex     = 0xFF_FF
	hexFlt  = 0x1.8p-3
	bin     = 0b1010_0101
	oct     = 0o755
	legacy  = 0755
	float   = 1_000.25e-3
	leading = .5e10
	imag    = 3.14i
	runeA   = 'a'
	runeEsc = '\''
	runeUni = '\u00e9'
	runeHex = '\x7f'
)

type Number interface {
	~int | ~int64 | ~float64
}

type Tree[K comparable, V any] struct {
	Left, Right *Tree[K, V]
	Key         K
	Value       V `json:"value,omitempty" db:"val"`
}

func (t *Tree[K, V]) Walk(fn func(K, V) bool) bool {
	if t == nil {
		return true
	}
	return t.Left.Walk(fn) && fn(t.Key, t.Value) && t.Right.Walk(fn)
}

func Sum[T Number](xs ...T) (total T) {
	for _, x := range xs {
		total += x
	}
	return
}

func strings_() string {
	interp := "tab\there \"quoted\" \\ backslash \u2764 \x41"
	raw := `C:\no\escapes\here "quotes" too`
	multiRaw := `line one
line two with "quotes" and \n literally
	indented line three`
	// interpreted strings end at the line, so this one is unterminated:
	broken := "oops no closing quote
	recovered := "next line is fine"
	return interp + raw + multiRaw + broken + recovered
}

func concurrency(ctx context.Context) error {
	ch := make(chan int, 10)
	done := make(chan struct{})
	var results map[string][]int = map[string][]int{}

	go func() {
		defer close(done)
		for v := range ch {
			results["even"] = append(results["even"], v)
		}
	}()

	for i := 0; i < cap(ch); i++ {
		select {
		case ch <- i:
		case <-ctx.Done():
			return ctx.Err()
		default:
			goto cleanup
		}
	}
cleanup:
	close(ch)
	<-done

	switch n := len(results); {
	case n == 0:
		fallthrough
	case n > 100:
		panic(errors.New("unexpected"))
	}
	return nil
}

func typeSwitch(v any) string {
	switch x := v.(type) {
	case nil:
		return "nil"
	case int, int8, int16, int32, int64:
		return fmt.Sprintf("int %d", x)
	case func(string) error:
		return "func"
	case []byte:
		return str.ToUpper(string(x))
	}
	return ""
}

func main() {
	defer func() {
		if r := recover(); r != nil {
			println("recovered", r)
		}
	}()
	t := &Tree[string, int]{Key: "a", Value: 1}
	t.Walk(func(k string, v int) bool { fmt.Println(k, v); return true })
	fmt.Println(Sum(1, 2, 3), Sum(1.5, 2.5), KB, MB, GB, strings_())
	_ = concurrency(context.Background())
}
