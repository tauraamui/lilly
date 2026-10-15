// TypeScript syntax stress file. Lexing only.
import type { Readable } from 'node:stream';
import * as path from "node:path";

/**
 * A generic, branded, recursive mess.
 * @template T
 */
export type Brand<T, B extends string> = T & { readonly __brand: B };
type UserId = Brand<string, 'UserId'>;

type DeepPartial<T> = T extends object
  ? { [K in keyof T]?: DeepPartial<T[K]> }
  : T;

type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

type Route = `/${string}/${number}` | `/static/${'css' | 'js'}`;
type ElementOf<T> = T extends readonly (infer E)[] ? E : never;
type Fn = (...args: unknown[]) => void;
type Ctor = abstract new (...args: any[]) => object;
type IsString<T> = [T] extends [string] ? true : false;

declare module 'virtual:config' {
  export const values: Record<string, symbol | bigint>;
}

declare global {
  interface Window {
    __LILLY__?: { version: string };
  }
}

namespace Geometry {
  export interface Point {
    readonly x: number;
    readonly y: number;
    z?: number;
  }
}

enum Direction { Up = 1, Down, Left = 'LEFT', Right = `RIGHT`.length }
const enum Flags { None = 0, A = 1 << 0, B = 1 << 1, AB = A | B }

abstract class Shape<T extends Geometry.Point = Geometry.Point> implements Iterable<T> {
  protected abstract readonly points: T[];
  private static count = 0;
  public override toString(): string {
    return `Shape(${this.points.map((p) => `${p.x},${p.y}`).join(' ')})`;
  }
  *[Symbol.iterator](): Iterator<T> {
    yield* this.points;
  }
}

function assertIsDefined<T>(val: T, msg?: string): asserts val is NonNullable<T> {
  if (val === undefined || val === null) {
    throw new Error(msg ?? `expected value, got ${val}`);
  }
}

function isUserId(x: unknown): x is UserId {
  return typeof x === 'string' && x.startsWith('u_');
}

const config = {
  port: 0x1F90,
  ratio: 1.5e-3,
  big: 9_007_199_254_740_993n,
  paths: ['a', "b", `c`] as const,
} satisfies Record<string, unknown>;

function overloaded(x: string): string;
function overloaded(x: number): number;
function overloaded(x: string | number): string | number {
  return x;
}

// generic call vs comparison: both should lex as plain operators
const a = overloaded<string>('x');
const b = (1 < 2) > (3 > 4);

const unique: unique symbol = Symbol('u');
let definite!: number;
const nonNull = document.getElementById('app')!;
const cast = <HTMLDivElement>nonNull;
const asCast = nonNull as unknown as HTMLDivElement;

/* decorators */
function sealed(target: Function) {}
@sealed
class Decorated {
  @Reflect.metadata('k', 'v') method(@inject() dep: string) {}
}

const tpl = `multi
  line ${config.paths.map((p) => {
    const nested = { p, deep: { ok: true } };
    return `${nested.p}:${nested.deep.ok}`;
  }).join(', ')}
done`;
export { tpl, Direction, Flags, assertIsDefined, isUserId };
