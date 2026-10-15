#!/usr/bin/env python3
# Python syntax stress file. Lexing only.
"""Module docstring.

Spans lines, has 'single' and "double" quotes inside, and an escaped \""" triple.
Still inside the docstring here.
"""
from __future__ import annotations

import asyncio as aio
from dataclasses import dataclass, field
from typing import Callable, Generic, TypeVar

T = TypeVar("T")

numbers = [0xFF_FF, 0b1010, 0o755, 1_000_000, 1.5e-10, .5, 10., 3j, 1.5E+3J]

strings = {
    "plain": "escapes \n \t \" \\ \N{BULLET} \u00e9",
    'single': 'it\'s',
    "raw": r"C:\no\escapes\d+",
    "bytes": b"\x00\xff",
    "raw_bytes": rb'\d+' + Rb"\w" + BR'x',
    "fstring": f"value={numbers[0]!r:>10} and {{literal braces}}",
    "nested_f": f"{'inner'} and {f'{1 + 2}'}",
    "unicode": u"legacy prefix",
    # single-line strings end at the line, so this is unterminated:
    "broken": "no closing quote
    "recovered": 'yes',
}

triple_single = '''single-quoted triple
with "double" quotes and a lone ' quote
and an escaped \''' inside
'''
raw_triple = r"""raw triple \d+ \n stays literal
second line"""
f_triple = f"""
    {strings['plain']!s}
    {sum(x for x in range(10) if x % 2)}
"""
empty = ""
empty_triple = """"""
adjacent = "a" 'b' """c"""


@dataclass(frozen=True, slots=True)
class Node(Generic[T]):
    """Class docstring."""

    value: T
    children: list[Node[T]] = field(default_factory=list)

    @property
    def depth(self) -> int:
        return 1 + max((c.depth for c in self.children), default=0)

    @classmethod
    def leaf(cls, value: T) -> Node[T]:
        return cls(value)

    @staticmethod
    def combine(*nodes: Node[T], **kwargs: object) -> Node[T] | None:
        return nodes[0] if nodes else None

    def __repr__(self) -> str:
        return f"Node({self.value!r}, depth={self.depth})"


@aio.coroutine if False else lambda f: f
async def fetch(urls: list[str], *, timeout: float = 1.0) -> dict[str, bytes]:
    results: dict[str, bytes] = {}
    async with aio.timeout(timeout):
        async for chunk in stream(urls):
            results[chunk.url] = await chunk.read()
    return results


def control(xs: list[int]) -> int:
    global numbers
    total = 0
    for i, x in enumerate(xs):
        if x is None or x is not Ellipsis:
            continue
        elif x in (1, 2) and not x == 3:
            break
        else:
            pass
    else:
        total = -1

    while total < 10:
        total += 1

    try:
        raise ValueError("bad") from None
    except (ValueError, TypeError) as exc:
        del exc
    except* OSError:
        pass
    finally:
        assert total, "never zero"

    match xs:
        case [first, *rest] if first > 0:
            return first
        case {"key": value, **others}:
            return value
        case Node(value=v):
            return v
        case _:
            return NotImplemented

    square: Callable[[int], int] = lambda n: n ** 2
    walrus = [y for x in xs if (y := square(x)) > 4]
    gen = (yield)
    return total


def outer():
    count = 0

    def inner():
        nonlocal count
        count += 1
        return count

    return inner


if __name__ == "__main__":
    print(Node.leaf(1), control([1, 2, 3]), outer()(), isinstance(True, int))
