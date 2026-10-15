//// Module doc comment (four slashes).
//// Gleam syntax stress file. Lexing only.

import gleam/io
import gleam/list.{map, fold}
import gleam/int as integer
import gleam/result.{type Result as R}

/// Doc comment on a type.
pub type Shape {
  Circle(radius: Float)
  Rectangle(width: Float, height: Float)
  Polygon(points: List(#(Float, Float)))
}

pub opaque type Counter {
  Counter(value: Int)
}

pub type Pair(a, b) =
  #(a, b)

const numbers = [0xFF_FF, 0b1010, 0o755, 1_000_000, 1.5e-10, 10.0, -3]

const strings = [
  "escapes \n \t \" \\ \u{1F600}",
  "a string
that spans
several lines",
  "",
]

@external(erlang, "erlang", "system_time")
@external(javascript, "./ffi.mjs", "now")
fn now() -> Int

@deprecated("use area/1")
pub fn old_area(s: Shape) -> Float {
  area(s)
}

pub fn area(shape: Shape) -> Float {
  case shape {
    Circle(radius: r) -> 3.14159 *. r *. r
    Rectangle(width: w, height: h) if w >. 0.0 -> w *. h
    Rectangle(..) -> 0.0
    Polygon([]) | Polygon([_]) -> 0.0
    Polygon([first, ..rest]) -> {
      let #(x, y) = first
      x +. y +. int_to_float(list.length(rest))
    }
  }
}

fn int_to_float(n: Int) -> Float {
  integer.to_float(n)
}

pub fn pipelines(xs: List(Int)) -> Result(Int, String) {
  use x <- result.try(list.first(xs) |> result.replace_error("empty"))
  let total =
    xs
    |> map(fn(n) { n * 2 })
    |> fold(0, fn(acc, n) { acc + n })
  let assert True = total >= x
  let labelled = Counter(value: total)
  let Counter(value: v) = labelled
  case v {
    0 -> Error("zero")
    n if n > 100 -> panic as "too big"
    _ -> Ok(v)
  }
}

pub fn bits() -> BitArray {
  let header = <<0xCA, 0xFE:size(16), 3:unsigned-little-size(32)>>
  let text = <<"hello":utf8, 233:utf8_codepoint>>
  let assert <<first:bytes-size(2), rest:bits>> = header
  echo rest
  <<first:bits, text:bits>>
}

pub fn placeholder() -> Nil {
  todo as "not written yet"
}

pub fn main() {
  io.println("area: " <> float_string(area(Circle(1.0))))
  let _ = now()
  Nil
}

fn float_string(f: Float) -> String {
  case f >. 1.0 {
    True -> "big"
    False -> "small"
  }
}
