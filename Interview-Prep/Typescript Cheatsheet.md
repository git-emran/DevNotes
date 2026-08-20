# TypeScript Interview Cheatsheet — Written Test Edition

 *Type-system fundamentals, output/error-prediction traps, and the "why" behind each answer.*

 ---

 ## 1. `type` vs. `interface`

 Both describe object shapes. Key differences:

 - `interface` supports **declaration merging** (redeclaring adds to it); `type` doesn't.
- `type` can express unions, intersections, tuples, and primitives directly; `interface` can only describe object/class shapes.

 ```ts
interface User { name: string }
interface User { age: number }   // merges! User now has name AND age

type ID = string | number;        // interface can't do this
```

 **Clever framing:** "Reach for `interface` when modeling an object that might be extended later (like a public API); reach for `type` for unions, tuples, or anything algebraic."

 ---

## 2. `any` vs. `unknown`

 `any` disables type checking entirely. `unknown` is type-safe — you can assign anything to it, but you must narrow it before using it.

 ```ts
let a: any = "hi";
a.toUpperCase();      // no error, even if wrong

let u: unknown = "hi";
u.toUpperCase();       // Error: Object is of type 'unknown'
if (typeof u === "string") u.toUpperCase();  // OK after narrowing
```

 ---

 ## 3. Structural Typing ("Duck Typing")

 TypeScript compares shapes, not declared names — two unrelated types are compatible if their structures match.

 ```ts
interface Point { x: number; y: number }
function log(p: Point) { console.log(p.x, p.y) }

log({ x: 1, y: 2, z: 3 });   // OK! extra props allowed via variable
const obj = { x: 1, y: 2, z: 3 };
log(obj);                     // fine — structural match

log({ x: 1, y: 2, z: 3 });   // literal directly: ERROR — "excess property check"
```

 **Gotcha:** object *literals* passed directly get stricter excess-property checks than variables do.

 ---

 ## 4. Union vs. Intersection Types

 ```ts
type A = { name: string };
type B = { age: number };

type Union = A | B;          // has EITHER shape
type Intersection = A & B;   // has BOTH — name AND age
```

 ---

 ## 5. Type Narrowing

 ```ts
function process(x: string | number) {
  if (typeof x === "string") {
    return x.toUpperCase();   // TS knows x is string here
  }
  return x.toFixed(2);        // TS knows x is number here
}
```

 Common narrowing tools: `typeof`, `instanceof`, `in`, discriminated unions, and custom **type guards**.

 ---

 ## 6. Custom Type Guards

 ```ts
interface Cat { meow(): void }
interface Dog { bark(): void }

function isCat(animal: Cat | Dog): animal is Cat {
  return (animal as Cat).meow !== undefined;
}
```

 The `animal is Cat` return type is a **type predicate** — it tells the compiler how to narrow after the check.

 ---

 ## 7. Discriminated Unions

 ```ts
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "square"; side: number };

function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return Math.PI * s.radius ** 2;
    case "square": return s.side ** 2;
  }
}
```

 The shared literal field (`kind`) lets TS narrow the whole union safely — this is the idiomatic way to model variant data in TS.

 ---

 ## 8. Generics

 ```ts
function identity<T>(arg: T): T {
  return arg;
}

function firstElement<T>(arr: T[]): T | undefined {
  return arr[0];
}

interface Box<T> { value: T }
const b: Box<string> = { value: "hi" };
```

 **Clever framing:** "Generics are how you write a function once and let the type system fill in the blank instead of you writing it five times for five types."

 ---

 ## 9. Generic Constraints (`extends`)

 ```ts
function getLength<T extends { length: number }>(item: T): number {
  return item.length;
}

getLength("hello");     // OK — strings have .length
getLength([1, 2, 3]);   // OK — arrays have .length
getLength(42);           // Error — number has no .length
```

 ---

 ## 10. `keyof`, `typeof`, Indexed Access

 ```ts
interface Person { name: string; age: number }
type PersonKeys = keyof Person;         // "name" | "age"

const p = { name: "Sam", age: 30 };
type PType = typeof p;                   // { name: string; age: number }

type NameType = Person["name"];          // string
```

 ---

 ## 11. Mapped Types

 ```ts
type Readonly2<T> = { readonly [K in keyof T]: T[K] };
type Partial2<T> = { [K in keyof T]?: T[K] };
type Nullable<T> = { [K in keyof T]: T[K] | null };
```

 TS's built-in `Partial<T>`, `Readonly<T>`, `Pick<T, K>`, `Omit<T, K>`, `Record<K, V>` are all mapped types under the hood.

 ---

 ## 12. `Partial`, `Pick`, `Omit`, `Record` — Utility Types

 ```ts
interface User { id: number; name: string; email: string }

type PartialUser = Partial<User>;              // all props optional
type UserPreview = Pick<User, "id" | "name">;  // only id + name
type UserNoEmail = Omit<User, "email">;         // everything but email
type Roles = Record<"admin" | "user", string[]>; // { admin: string[]; user: string[] }
```

 ---

 ## 13. Conditional Types

 ```ts
type IsString<T> = T extends string ? true : false;
type A = IsString<"hi">;   // true
type B = IsString<42>;      // false

type ElementType<T> = T extends (infer U)[] ? U : T;
type C = ElementType<number[]>;  // number
```

 `infer` extracts a type from within another type — this is how `ReturnType<T>` and `Parameters<T>` are implemented internally.

 ---

 ## 14. `enum` vs. Union of String Literals

 ```ts
enum Direction { Up, Down, Left, Right }   // compiles to a real JS object

type Direction2 = "up" | "down" | "left" | "right";  // erased at compile time, zero runtime cost
```

 **Clever framing:** "Most modern TS style guides prefer literal unions over `enum` — enums generate actual runtime code and have quirks (like numeric enums being bidirectionally mapped), while literal unions are pure compile-time safety with no output at all."

 ---

 ## 15. `const` Assertions

 ```ts
let color = "red";              // type: string
let color2 = "red" as const;    // type: "red" (literal, readonly)

const point = { x: 1, y: 2 } as const;
// type: { readonly x: 1; readonly y: 2 }
```

 ---

 ## 16. Optional Chaining & Nullish Coalescing

 ```ts
const city = user?.address?.city;        // undefined if any link is null/undefined
const name = user.name ?? "Anonymous";   // only falls back on null/undefined, NOT "" or 0
```

 **Gotcha:** `??` differs from `||` — `0 || "default"` gives `"default"`, but `0 ?? "default"` gives `0`.

 ---

 ## 17. Function Overloads

 ```ts
function combine(a: string, b: string): string;
function combine(a: number, b: number): number;
function combine(a: any, b: any): any {
  return a + b;
}
```

 Multiple signatures describe valid call shapes; the final implementation signature is not visible to callers.

 ---

 ## 18. `readonly` and `as const` Arrays/Tuples

 ```ts
const arr: readonly number[] = [1, 2, 3];
arr.push(4);   // Error — push doesn't exist on readonly array

type Point = readonly [number, number];
const p: Point = [1, 2];
p[0] = 5;      // Error
```

 ---

 ## 19. Class Access Modifiers

 ```ts
class Animal {
  public name: string;        // accessible anywhere (default)
  private secret: string;      // only inside this class
  protected age: number;       // this class + subclasses
  readonly id: number;         // can't be reassigned after construction

  constructor(name: string, id: number) {
    this.name = name;
    this.id = id;
  }
}
```

 ---

 ## 20. Abstract Classes

 ```ts
abstract class Shape {
  abstract area(): number;      // no implementation — subclasses MUST provide one
  describe(): string {
    return `Area: ${this.area()}`;
  }
}

class Circle extends Shape {
  constructor(private radius: number) { super(); }
  area() { return Math.PI * this.radius ** 2; }
}
```

 You can't `new Shape()` directly — abstract classes exist to be extended.

 ---

 ## 21. `never` Type

 Represents a value that can never occur — functions that always throw, or infinite loops.

 ```ts
function fail(msg: string): never {
  throw new Error(msg);
}
```

 Also useful for **exhaustiveness checking** in switch statements over unions:

 ```ts
function assertNever(x: never): never {
  throw new Error("Unexpected value: " + x);
}
```

 ---

 ## 22. `void` vs. `undefined`

 `void` means "the return value should be ignored" (used for function return types). `undefined` is an actual value a variable can hold. A function typed `(): void` can still technically return something — TS just won't let callers use that value.

 ---

 ## 23. Type Assertions (`as`) — and Why They're Risky

 ```ts
const input = document.getElementById("email") as HTMLInputElement;
input.value;   // TS trusts you here — no runtime check happens
```

 **Clever framing:** "`as` is you telling the compiler 'trust me' — it doesn't validate anything at runtime, so a wrong assertion just moves the bug from compile time to production."

 ---

 ## 24. Non-Null Assertion Operator (`!`)

 ```ts
function getUser(id: string): User | undefined { /* ... */ }
const user = getUser("1")!;   // "I know this isn't undefined" — no runtime check
```

 Same risk category as `as` — it silences the compiler, not the actual possibility of `undefined`.

 ---

 ## 25. Index Signatures

 ```ts
interface StringMap {
  [key: string]: string;
}

const scores: { [name: string]: number } = { alice: 90, bob: 85 };
```

 Useful for objects with dynamic keys where you don't know the exact property names ahead of time.

 ---

 ## 26. Function Types vs. Method Signatures (this-binding gotcha)

 ```ts
interface A {
  method(): void;        // method shorthand — `this` types are bivariant, less strict
  fn: () => void;         // arrow-style property — stricter `this` checking
}
```

 Prefer arrow-style function properties in interfaces when you want TS to strictly check `this` context, especially with inheritance.

 ---

 ## 27. Template Literal Types

 ```ts
type Greeting = `Hello, ${string}!`;
const g: Greeting = "Hello, Sam!";   // OK
const bad: Greeting = "Hi, Sam!";     // Error

type EventName<T extends string> = `on${Capitalize<T>}`;
type ClickEvent = EventName<"click">;  // "onClick"
```

 ---

 ## 28. Module `import type` / `export type`

 ```ts
import type { User } from "./types";   // erased at compile time — zero runtime import
import { fetchUser } from "./api";     // real runtime import
```

 `import type` guarantees the import is purely for types and won't appear in compiled JS — useful for avoiding circular-import runtime issues.

 ---

 ## 29. Strict Mode Flags Worth Knowing

 - `strictNullChecks`: `null`/`undefined` aren't silently assignable to every type.
- `noImplicitAny`: untyped parameters raise an error instead of defaulting to `any`.
- `strictFunctionTypes`: function parameters are checked contravariantly (stricter).
- `strict`: turns on all of the above (and more) at once — the recommended baseline.

 ---

 ## 30. Common Output/Error-Prediction Traps

 ```ts
// Trap 1: excess property check only on literals
interface Config { debug: boolean }
function setup(c: Config) {}
setup({ debug: true, verbose: true });  // Error: excess property 'verbose'
const cfg = { debug: true, verbose: true };
setup(cfg);                              // OK — no error via variable

// Trap 2: `any` poisons everything downstream
function parse(json: any) {
  const data = json.whatever.deeply.nested;  // no error, ever — any spreads
}

// Trap 3: array holes with `!`
const arr: number[] = [1, 2, 3];
const x = arr[10];   // type is `number`, but value is actually `undefined` at runtime
                       // (unless noUncheckedIndexedAccess is on)

// Trap 4: enum reverse mapping (numeric enums only)
enum Status { Active, Inactive }
console.log(Status[0]);   // "Active" — numeric enums map both directions

// Trap 5: optional property vs. `| undefined`
interface Foo { a?: number }        // key can be OMITTED entirely
interface Bar { a: number | undefined }  // key must be PRESENT, value can be undefined
const foo: Foo = {};                 // OK
const bar: Bar = {};                  // Error — 'a' is missing
```

 ---

 ### Quick recall table

 | Topic | One-line hook |
| --- | --- |
| `type`vs`interface` | Algebraic vs. mergeable object shapes |
| `any`vs`unknown` | Disables checking vs. forces narrowing |
| Structural typing | Shape matters, not the declared name |
| Discriminated unions | Shared literal tag narrows the whole variant |
| `as const` | Widens nothing — locks in literal types |
| `??`vs ` |  |
| `never` | Exhaustiveness checks + functions that never return |
| `as`/`!` | Compiler trust with zero runtime guarantee |
| Excess property check | Only triggers on object literals, not variables |