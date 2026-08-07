# Tutorial: Tic-Tac-Toe in Angular

 This tutorial walks you through building a small but complete tic-tac-toe game in Angular, mirroring the classic React tic-tac-toe tutorial step for step. By the end you'll have:

 - A working, playable tic-tac-toe game
- A "time travel" feature that lets you jump back to any previous move
- A solid feel for Angular fundamentals: **standalone components**, **`@Input`/`@Output`**, **signals**, **computed state**, and the **`@for`/`@if`** control-flow syntax

 We'll use modern Angular (standalone components + signals, the default since Angular 17+), and — matching how real Angular projects are structured — every component gets its own `.ts`, `.html`, and `.css` files rather than inline templates.

 ---

 ## What You're Building

 A 3×3 board on the left, and a move-history list ("time travel") on the right. Click any empty square to place the current player's mark; the app tracks winners and lets you jump back to any earlier board state.

 ---

 ## Prerequisites

 This tutorial assumes basic familiarity with HTML, CSS, and JavaScript/TypeScript, and some conceptual familiarity with components and props/state from any framework. You don't need prior Angular experience — each new concept is explained the first time it's used.

 ---

 ## Project Setup

 ### Option A: StackBlitz (fastest, no install)

 Go to **angular.new** — it spins up a full Angular project in the browser in seconds, already using the standalone-component style this tutorial follows. This is the quickest way to follow along without installing anything locally.

 ### Option B: Local setup with Angular CLI

 Install the CLI globally (only needed once per machine):

 ```bash
npm install -g @angular/cli
```

 Generate a new project. The flags below give you standalone components (no `NgModule` boilerplate), plain CSS, and skip Angular's router since this app doesn't need one:

 ```bash
ng new tic-tac-toe --standalone --style=css --routing=false
cd tic-tac-toe
```

 Start the dev server:

 ```bash
ng serve
```

 Open `http://localhost:4200` — you should see the default Angular starter page. Leave `ng serve` running in a terminal; it will live-reload as you edit files.

 ### Understand the generated project structure

 The CLI scaffolds a fair amount. Here's what you'll actually touch in this tutorial versus what you can ignore:

 ```
tic-tac-toe/
├── src/
│   ├── app/
│   │   ├── app.component.ts        <- root component (we'll edit this)
│   │   ├── app.component.html      <- root component's template (we'll edit this)
│   │   ├── app.component.css       <- root component's styles (we'll edit this)
│   │   └── app.config.ts           <- app-wide providers (leave as-is)
│   ├── index.html                  <- the single HTML page hosting the app (leave as-is)
│   ├── main.ts                     <- bootstraps AppComponent (leave as-is)
│   └── styles.css                  <- global styles (optional edits)
├── angular.json                    <- CLI/build configuration (leave as-is)
├── package.json
└── tsconfig.json
```

 We'll add three new component folders alongside `app.component.*`:

 ```
src/app/
├── app.component.ts
├── app.component.html
├── app.component.css
├── square/
│   ├── square.component.ts
│   ├── square.component.html
│   └── square.component.css
├── board/
│   ├── board.component.ts
│   ├── board.component.html
│   └── board.component.css
└── game/
    ├── game.component.ts
    ├── game.component.html
    └── game.component.css
```

 That's the `Square → Board → Game` hierarchy from the React tutorial, just with each component's TypeScript class, markup, and styles split into their own files — the convention you'll find in essentially every real-world Angular codebase, and what `ng generate component` produces by default.

 > **Tip:** you can create each component's three files instantly with the CLI generator instead of by hand, e.g. `ng generate component square` (or the shorthand `ng g c square`). It also automatically updates any `spec.ts` test scaffolding. This tutorial shows the file contents directly so you can see exactly what belongs where, but feel free to use the generator and just replace its output.

 ---

 ## Step 1: Building the Square Component

 Let's start with the smallest building block: a single square. Create a `square/` folder under `src/app/` with three files.

 **📄 `src/app/square/square.component.ts`**

 ```typescript
import { Component } from '@angular/core';

@Component({
  selector: 'app-square',
  standalone: true,
  templateUrl: './square.component.html',
  styleUrl: './square.component.css',
})
export class SquareComponent {}
```

 **📄 `src/app/square/square.component.html`**

 ```html
<button class="square">X</button>
```

 **📄 `src/app/square/square.component.css`**

 ```css
.square {
  background: #fff;
  border: 1px solid #999;
  float: left;
  font-size: 24px;
  font-weight: bold;
  line-height: 34px;
  height: 34px;
  margin-right: -1px;
  margin-top: -1px;
  padding: 0;
  text-align: center;
  width: 34px;
}
```

 A few things to note, since these are the Angular equivalents of React concepts you may already know:

 - `standalone: true` means this component doesn't need to be declared in an `NgModule` — you just import it directly wherever it's used. This is the modern, default way to write Angular components.
- `selector: 'app-square'` is the custom HTML tag other templates will use to render this component: `<app-square></app-square>`.
- `templateUrl` points at the `.html` file that holds this component's markup — the Angular equivalent of JSX, just kept in its own file. Unlike JSX, it's plain HTML with some added syntax (we'll use bindings like `[value]` and `(click)` shortly).
- `styleUrl` points at the `.css` file scoped to *just this component* — Angular automatically prevents these styles from leaking out and affecting other components, similar in spirit to CSS Modules.

 Now render one `Square` from the app root temporarily, just to check it works.

 **📄 `src/app/app.component.ts`**

 ```typescript
import { Component } from '@angular/core';
import { SquareComponent } from './square/square.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [SquareComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
})
export class AppComponent {}
```

 **📄 `src/app/app.component.html`**

 ```html
<app-square></app-square>
```

 Notice `imports: [SquareComponent]` in the `@Component` decorator — in standalone Angular, any child component you use in a template must be explicitly imported into the parent's TypeScript class, even though the template itself lives in a separate `.html` file. This is analogous to `import Square from './Square'` in a React file, just declared in the decorator instead of only at the top of the file.

 Reload the page (or empty out the boilerplate `app.component.html` first if the CLI generated extra content) — you should see a single square with an "X" in it.

 ---

 ## Step 2: Passing Data with `@Input`

 Right now every square is hardcoded to show "X". We want each square to display whatever value it's given — `'X'`, `'O'`, or nothing.

 In React, you'd pass a prop: `<Square value="X" />`. In Angular, the equivalent is an **`@Input()`** property.

 **📄 `src/app/square/square.component.ts`**

 ```typescript
import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-square',
  standalone: true,
  templateUrl: './square.component.html',
  styleUrl: './square.component.css',
})
export class SquareComponent {
  @Input() value: string | null = null;
}
```

 **📄 `src/app/square/square.component.html`**

 ```html
<button class="square">{{ value }}</button>
```

 *(`square.component.css` is unchanged from Step 1.)*

 Two new pieces of syntax here:

 - `@Input() value` declares a property that the *parent* component can set from its template, just like a prop.
- `{{ value }}` is **interpolation** — it drops the current value of `value` into the rendered HTML. This is Angular's equivalent of `{value}` in JSX.

 Try it from the root component:

 **📄 `src/app/app.component.html`**

 ```html
<app-square [value]="'X'"></app-square>
```

 The brackets `[value]` tell Angular "evaluate this as a TypeScript expression" rather than treating it as a literal string. That's a distinction worth remembering: `value="X"` (no brackets) passes the literal string `"X"`, while `[value]="someExpression"` evaluates `someExpression` in the component's TypeScript context. You'll use `[value]="..."` almost everywhere once real data is involved.

 ---

 ## Step 3: Building the Board

 Now let's build the `Board` component, which renders nine squares in a 3×3 grid and will eventually own the game's state. Create a `board/` folder under `src/app/`.

 **📄 `src/app/board/board.component.ts`**

 ```typescript
import { Component } from '@angular/core';
import { SquareComponent } from '../square/square.component';

@Component({
  selector: 'app-board',
  standalone: true,
  imports: [SquareComponent],
  templateUrl: './board.component.html',
  styleUrl: './board.component.css',
})
export class BoardComponent {}
```

 **📄 `src/app/board/board.component.html`**

 ```html
<div class="board-row">
  <app-square value="1"></app-square>
  <app-square value="2"></app-square>
  <app-square value="3"></app-square>
</div>
<div class="board-row">
  <app-square value="4"></app-square>
  <app-square value="5"></app-square>
  <app-square value="6"></app-square>
</div>
<div class="board-row">
  <app-square value="7"></app-square>
  <app-square value="8"></app-square>
  <app-square value="9"></app-square>
</div>
```

 **📄 `src/app/board/board.component.css`**

 ```css
.board-row:after {
  clear: both;
  content: '';
  display: table;
}
```

 Note the relative import path `'../square/square.component'` — since `board.component.ts` lives in `src/app/board/`, it steps up one level (`../`) and into `square/` to find it.

 Update the root component to render `<app-board>` instead of a bare `<app-square>`, and import `BoardComponent` in `app.component.ts`:

 **📄 `src/app/app.component.ts`**

 ```typescript
import { Component } from '@angular/core';
import { BoardComponent } from './board/board.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [BoardComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
})
export class AppComponent {}
```

 **📄 `src/app/app.component.html`**

 ```html
<app-board></app-board>
```

 Reload — you should see a static 3×3 grid numbered 1 through 9. We'll replace those hardcoded numbers with real game state next.

 ---

 ## Step 4: Making Squares Clickable

 A React tutorial reader would add an `onClick` handler prop here. Angular's equivalent for "a child notifying its parent that something happened" is `@Output()` paired with an `EventEmitter`.

 **📄 `src/app/square/square.component.ts`**

 ```typescript
import { Component, Input, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-square',
  standalone: true,
  templateUrl: './square.component.html',
  styleUrl: './square.component.css',
})
export class SquareComponent {
  @Input() value: string | null = null;
  @Output() onClick = new EventEmitter<void>();
}
```

 **📄 `src/app/square/square.component.html`**

 ```html
<button class="square" (click)="onClick.emit()">
  {{ value }}
</button>
```

 New syntax:

 - `(click)="onClick.emit()"` is an **event binding**. Parentheses mean "listen for this DOM event," and the expression runs when it fires — here, calling `.emit()` on our `EventEmitter`. This is the Angular equivalent of `onClick={handleClick}` in JSX.
- `@Output() onClick = new EventEmitter<void>()` declares a custom event the parent can listen to, the same way `onSquareClick` would be a callback prop in React.

 The parent listens using the same parenthesis syntax, matching the `@Output()` name:

 ```html
<app-square [value]="'X'" (onClick)="handleClick()"></app-square>
```

 We'll wire this up for real in the next step.

 ---

 ## Step 5: Lifting State Up — the Board Owns the Squares

 Just like in React, each `Square` shouldn't manage its own state independently — if it did, the `Board` (and the game logic) would have no way to know the overall board state or detect a winner. Instead, **the `Board` lifts state up** and owns a single array of nine values, passing each square its value and a click handler.

 Angular's modern way to hold reactive state is a **signal**. A signal is a wrapper around a value that Angular can track: read it by calling it like a function (`mySignal()`), and update it with `.set()` or `.update()`. Angular automatically re-renders any template that reads a signal whenever it changes — no manual "setState" plumbing required.

 **📄 `src/app/board/board.component.ts`**

 ```typescript
import { Component, signal } from '@angular/core';
import { SquareComponent } from '../square/square.component';

@Component({
  selector: 'app-board',
  standalone: true,
  imports: [SquareComponent],
  templateUrl: './board.component.html',
  styleUrl: './board.component.css',
})
export class BoardComponent {
  squares = signal<(string | null)[]>(Array(9).fill(null));

  handleClick(i: number) {
    const nextSquares = this.squares().slice();
    nextSquares[i] = 'X';
    this.squares.set(nextSquares);
  }
}
```

 **📄 `src/app/board/board.component.html`**

 ```html
<div class="board-row">
  <app-square [value]="squares()[0]" (onClick)="handleClick(0)"></app-square>
  <app-square [value]="squares()[1]" (onClick)="handleClick(1)"></app-square>
  <app-square [value]="squares()[2]" (onClick)="handleClick(2)"></app-square>
</div>
<div class="board-row">
  <app-square [value]="squares()[3]" (onClick)="handleClick(3)"></app-square>
  <app-square [value]="squares()[4]" (onClick)="handleClick(4)"></app-square>
  <app-square [value]="squares()[5]" (onClick)="handleClick(5)"></app-square>
</div>
<div class="board-row">
  <app-square [value]="squares()[6]" (onClick)="handleClick(6)"></app-square>
  <app-square [value]="squares()[7]" (onClick)="handleClick(7)"></app-square>
  <app-square [value]="squares()[8]" (onClick)="handleClick(8)"></app-square>
</div>
```

 *(`board.component.css` is unchanged from Step 3.)*

 Click any square — it should fill with an "X". We'll clean up the repetitive template (and add "O" turns) in the next couple of steps, but the core state-lifting pattern is now in place: **the `Board` is the single source of truth for all nine squares**, just as it is in the React version.

 ---

 ## Step 6: Why Immutability Matters

 Notice `handleClick` does this:

 ```typescript
const nextSquares = this.squares().slice();
nextSquares[i] = 'X';
this.squares.set(nextSquares);
```

 Instead of mutating `this.squares()[i]` directly. This matters for the same reasons it matters in React:

 1. **Change detection relies on new references.** Signals (and Angular's `OnPush` change detection more broadly) determine "did this update?" partly by checking whether the value changed. If you mutate an array in place and pass the *same* array reference back to `.set()`, Angular may not realize anything changed.
2. **It enables time travel.** We're about to build a move-history feature. If we mutated the same array on every move, every entry in our history would secretly point to the *same* array, and "jumping back" to an old move would show the current (wrong) state instead.
3. **It keeps components predictable.** A component that never mutates data it was given is much easier to reason about — the same discipline React encourages with props and state.

 So the rule going forward: **always create a new array (or object) instead of mutating the existing one.**

 ---

 ## Step 7: Taking Turns

 Right now every click places an "X". Let's alternate between "X" and "O", using a second signal to track whose turn it is.

 **📄 `src/app/board/board.component.ts`**

 ```typescript
import { Component, signal } from '@angular/core';
import { SquareComponent } from '../square/square.component';

@Component({
  selector: 'app-board',
  standalone: true,
  imports: [SquareComponent],
  templateUrl: './board.component.html',
  styleUrl: './board.component.css',
})
export class BoardComponent {
  squares = signal<(string | null)[]>(Array(9).fill(null));
  xIsNext = signal(true);
  status = () => 'Next player: ' + (this.xIsNext() ? 'X' : 'O');

  handleClick(i: number) {
    if (this.squares()[i]) {
      return; // square already filled — ignore the click
    }
    const nextSquares = this.squares().slice();
    nextSquares[i] = this.xIsNext() ? 'X' : 'O';
    this.squares.set(nextSquares);
    this.xIsNext.set(!this.xIsNext());
  }
}
```

 **📄 `src/app/board/board.component.html`**

 ```html
<div class="status">{{ status() }}</div>
<div class="board-row">
  <app-square [value]="squares()[0]" (onClick)="handleClick(0)"></app-square>
  <app-square [value]="squares()[1]" (onClick)="handleClick(1)"></app-square>
  <app-square [value]="squares()[2]" (onClick)="handleClick(2)"></app-square>
</div>
<div class="board-row">
  <app-square [value]="squares()[3]" (onClick)="handleClick(3)"></app-square>
  <app-square [value]="squares()[4]" (onClick)="handleClick(4)"></app-square>
  <app-square [value]="squares()[5]" (onClick)="handleClick(5)"></app-square>
</div>
<div class="board-row">
  <app-square [value]="squares()[6]" (onClick)="handleClick(6)"></app-square>
  <app-square [value]="squares()[7]" (onClick)="handleClick(7)"></app-square>
  <app-square [value]="squares()[8]" (onClick)="handleClick(8)"></app-square>
</div>
```

 **📄 `src/app/board/board.component.css`**

 ```css
.status { margin-bottom: 10px; }
.board-row:after { clear: both; content: ''; display: table; }
```

 Two additions worth calling out:

 - The early `return` when a square is already filled is the same defensive check the React tutorial adds — clicking a filled square (or a square after the game is won) should do nothing.
- `status` is a small function reading two signals; since it's called from the template with `status()`, Angular re-evaluates it whenever `squares` or `xIsNext` changes. (In the next step we'll upgrade this to a proper **computed signal**, which caches its result until a dependency changes — more efficient than a plain function for anything non-trivial.)

 ---

 ## Step 8: Declaring a Winner

 Now let's detect when someone has three in a row. Add a helper function at the bottom of `board.component.ts` (outside the class, same as a module-level helper in the React tutorial):

 **📄 `src/app/board/board.component.ts`**

 ```typescript
import { Component, computed, signal } from '@angular/core';
import { SquareComponent } from '../square/square.component';

@Component({
  selector: 'app-board',
  standalone: true,
  imports: [SquareComponent],
  templateUrl: './board.component.html',
  styleUrl: './board.component.css',
})
export class BoardComponent {
  squares = signal<(string | null)[]>(Array(9).fill(null));
  xIsNext = signal(true);

  winner = computed(() => calculateWinner(this.squares()));
  status = computed(() =>
    this.winner() ? 'Winner: ' + this.winner() : 'Next player: ' + (this.xIsNext() ? 'X' : 'O')
  );

  handleClick(i: number) {
    if (this.squares()[i] || this.winner()) {
      return;
    }
    const nextSquares = this.squares().slice();
    nextSquares[i] = this.xIsNext() ? 'X' : 'O';
    this.squares.set(nextSquares);
    this.xIsNext.set(!this.xIsNext());
  }
}

function calculateWinner(squares: (string | null)[]): string | null {
  const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6],           // diagonals
  ];
  for (const [a, b, c] of lines) {
    if (squares[a] && squares[a] === squares[b] && squares[a] === squares[c]) {
      return squares[a];
    }
  }
  return null;
}
```

 You now have a fully playable, winner-detecting game. Play a round and confirm "Winner: X" (or O) shows up correctly, and that clicks stop registering once someone has won.

 At this point, let's also simplify the repetitive HTML using `@for`, Angular's built-in control-flow syntax (the modern replacement for `*ngFor`):

 **📄 `src/app/board/board.component.html`**

 ```html
<div class="status">{{ status() }}</div>
@for (row of [0, 1, 2]; track row) {
  <div class="board-row">
    @for (col of [0, 1, 2]; track col) {
      <app-square
        [value]="squares()[row * 3 + col]"
        (onClick)="handleClick(row * 3 + col)">
      </app-square>
    }
  </div>
}
```

 `@for (item of items; track expr)` loops over a collection directly in the template — `track` tells Angular how to identify each item across re-renders (similar in purpose to React's `key` prop), which keeps re-rendering efficient and correct. Because this is plain HTML-file syntax rather than JSX, it reads as a template block rather than a JavaScript expression.

 ---

 ## Step 9: Lifting State Up Again — Introducing the Game Component

 So far `Board` owns everything. To add time travel, we need to store the *entire history* of board states, not just the current one — and per Step 5's "lift state up" principle, that history belongs one level higher, in a new `Game` component. `Board` becomes a "controlled" component: it receives its squares and `xIsNext` as inputs, and reports moves upward via an output, exactly like `Square` reports clicks to `Board`.

 Rewrite `board.component.ts` to accept props instead of owning state:

 **📄 `src/app/board/board.component.ts`**

 ```typescript
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { SquareComponent } from '../square/square.component';

@Component({
  selector: 'app-board',
  standalone: true,
  imports: [SquareComponent],
  templateUrl: './board.component.html',
  styleUrl: './board.component.css',
})
export class BoardComponent {
  @Input({ required: true }) xIsNext!: boolean;
  @Input({ required: true }) squares!: (string | null)[];
  @Output() play = new EventEmitter<(string | null)[]>();

  // Note: with squares now an @Input rather than a signal, we can't
  // build `status` as a computed signal off it directly. A plain getter
  // re-evaluates on every change-detection pass, which is perfectly fine
  // for a cheap calculation like this.
  get winner(): string | null {
    return calculateWinner(this.squares);
  }

  status(): string {
    return this.winner ? 'Winner: ' + this.winner : 'Next player: ' + (this.xIsNext ? 'X' : 'O');
  }

  handleClick(i: number) {
    if (this.squares[i] || this.winner) {
      return;
    }
    const nextSquares = this.squares.slice();
    nextSquares[i] = this.xIsNext ? 'X' : 'O';
    this.play.emit(nextSquares);
  }
}

function calculateWinner(squares: (string | null)[]): string | null {
  const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];
  for (const [a, b, c] of lines) {
    if (squares[a] && squares[a] === squares[b] && squares[a] === squares[c]) {
      return squares[a];
    }
  }
  return null;
}
```

 **📄 `src/app/board/board.component.html`** — unchanged from Step 8, since `squares()` and `status()` calls in the template still work the same way whether `squares` is a signal or a plain `@Input`. Wait — one adjustment is needed: `squares` is no longer a signal, so drop the trailing `()` when reading it:

 ```html
<div class="status">{{ status() }}</div>
@for (row of [0, 1, 2]; track row) {
  <div class="board-row">
    @for (col of [0, 1, 2]; track col) {
      <app-square
        [value]="squares[row * 3 + col]"
        (onClick)="handleClick(row * 3 + col)">
      </app-square>
    }
  </div>
}
```

 `@Input({ required: true })` marks an input as mandatory — Angular will give you a compile-time error if a parent forgets to bind it, similar to a required prop with no default in a typed React component.

 Now create a `game/` folder under `src/app/` for the component that owns the full move history.

 **📄 `src/app/game/game.component.ts`**

 ```typescript
import { Component, computed, signal } from '@angular/core';
import { BoardComponent } from '../board/board.component';

@Component({
  selector: 'app-game',
  standalone: true,
  imports: [BoardComponent],
  templateUrl: './game.component.html',
  styleUrl: './game.component.css',
})
export class GameComponent {
  history = signal<(string | null)[][]>([Array(9).fill(null)]);
  currentMove = signal(0);

  currentSquares = computed(() => this.history()[this.currentMove()]);
  xIsNext = computed(() => this.currentMove() % 2 === 0);

  handlePlay(nextSquares: (string | null)[]) {
    const nextHistory = [
      ...this.history().slice(0, this.currentMove() + 1),
      nextSquares,
    ];
    this.history.set(nextHistory);
    this.currentMove.set(nextHistory.length - 1);
  }

  jumpTo(nextMove: number) {
    this.currentMove.set(nextMove);
  }
}
```

 **📄 `src/app/game/game.component.html`**

 ```html
<div class="game">
  <div class="game-board">
    <app-board
      [xIsNext]="xIsNext()"
      [squares]="currentSquares()"
      (play)="handlePlay($event)">
    </app-board>
  </div>
  <div class="game-info">
    <ol>
      @for (move of history(); track $index; let i = $index) {
        <li>
          <button (click)="jumpTo(i)">
            {{ i > 0 ? 'Go to move #' + i : 'Go to game start' }}
          </button>
        </li>
      }
    </ol>
  </div>
</div>
```

 **📄 `src/app/game/game.component.css`**

 ```css
.game { display: flex; flex-direction: row; }
.game-info { margin-left: 20px; }
```

 Walking through the new pieces:

 - `history` is a signal holding an **array of board states** — one entry per move, starting with the empty board.
- `currentMove` tracks which entry in `history` we're currently viewing.
- `currentSquares` and `xIsNext` are **computed signals** derived from those two — exactly the derived-state pattern from the React tutorial (`currentSquares = history[currentMove]`), just expressed with Angular's `computed()`.
- `handlePlay` is the callback passed down as `(play)`. When the board reports a new move, we slice off any "future" moves beyond `currentMove` (this matters if you'd jumped back in time and then made a new move — it should overwrite the abandoned future, not append after it) and append the new board state.
- `@for (move of history(); track $index; let i = $index)` iterates the history array, exposing the current index as `i` via Angular's `let i = $index` syntax — the equivalent of `history.map((squares, move) => ...)` with `move` as the index in the React version.

 Finally, update the root component to render `<app-game>` instead of `<app-board>`.

 **📄 `src/app/app.component.ts`**

 ```typescript
import { Component } from '@angular/core';
import { GameComponent } from './game/game.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [GameComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
})
export class AppComponent {}
```

 **📄 `src/app/app.component.html`**

 ```html
<app-game></app-game>
```

 Reload the app. You now have full time travel: play a few moves, click any entry in the move list, and the board jumps back to that point in history. Making a new move from an earlier point correctly discards the "future" moves that came after it.

 ---

 ## Step 10: Polish — Highlight the Current Move

 One nice touch from the React tutorial: showing "You are at move #N" instead of a clickable button for whichever move is currently selected.

 **📄 `src/app/game/game.component.html`**

 ```html
<div class="game">
  <div class="game-board">
    <app-board
      [xIsNext]="xIsNext()"
      [squares]="currentSquares()"
      (play)="handlePlay($event)">
    </app-board>
  </div>
  <div class="game-info">
    <ol>
      @for (move of history(); track $index; let i = $index) {
        <li>
          @if (i === currentMove()) {
            <span>You are at move #{{ i }}</span>
          } @else {
            <button (click)="jumpTo(i)">
              {{ i > 0 ? 'Go to move #' + i : 'Go to game start' }}
            </button>
          }
        </li>
      }
    </ol>
  </div>
</div>
```

 `@if / @else` is Angular's built-in conditional syntax — the direct equivalent of a ternary or `&&` in JSX, just as a template block instead of an expression.

 ---

 ## Final File Tree

 ```
src/app/
├── app.component.ts
├── app.component.html
├── app.component.css
├── square/
│   ├── square.component.ts
│   ├── square.component.html
│   └── square.component.css
├── board/
│   ├── board.component.ts
│   ├── board.component.html
│   └── board.component.css
└── game/
    ├── game.component.ts
    ├── game.component.html
    └── game.component.css
```

 ### `square/square.component.ts`

 ```typescript
import { Component, Input, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-square',
  standalone: true,
  templateUrl: './square.component.html',
  styleUrl: './square.component.css',
})
export class SquareComponent {
  @Input() value: string | null = null;
  @Output() onClick = new EventEmitter<void>();
}
```

 ### `square/square.component.html`

 ```html
<button class="square" (click)="onClick.emit()">
  {{ value }}
</button>
```

 ### `square/square.component.css`

 ```css
.square {
  background: #fff;
  border: 1px solid #999;
  float: left;
  font-size: 24px;
  font-weight: bold;
  line-height: 34px;
  height: 34px;
  margin-right: -1px;
  margin-top: -1px;
  padding: 0;
  text-align: center;
  width: 34px;
}
```

 ### `board/board.component.ts`

 ```typescript
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { SquareComponent } from '../square/square.component';

@Component({
  selector: 'app-board',
  standalone: true,
  imports: [SquareComponent],
  templateUrl: './board.component.html',
  styleUrl: './board.component.css',
})
export class BoardComponent {
  @Input({ required: true }) xIsNext!: boolean;
  @Input({ required: true }) squares!: (string | null)[];
  @Output() play = new EventEmitter<(string | null)[]>();

  get winner(): string | null {
    return calculateWinner(this.squares);
  }

  status(): string {
    return this.winner ? 'Winner: ' + this.winner : 'Next player: ' + (this.xIsNext ? 'X' : 'O');
  }

  handleClick(i: number) {
    if (this.squares[i] || this.winner) {
      return;
    }
    const nextSquares = this.squares.slice();
    nextSquares[i] = this.xIsNext ? 'X' : 'O';
    this.play.emit(nextSquares);
  }
}

function calculateWinner(squares: (string | null)[]): string | null {
  const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];
  for (const [a, b, c] of lines) {
    if (squares[a] && squares[a] === squares[b] && squares[a] === squares[c]) {
      return squares[a];
    }
  }
  return null;
}
```

 ### `board/board.component.html`

 ```html
<div class="status">{{ status() }}</div>
@for (row of [0, 1, 2]; track row) {
  <div class="board-row">
    @for (col of [0, 1, 2]; track col) {
      <app-square
        [value]="squares[row * 3 + col]"
        (onClick)="handleClick(row * 3 + col)">
      </app-square>
    }
  </div>
}
```

 ### `board/board.component.css`

 ```css
.status { margin-bottom: 10px; }
.board-row:after { clear: both; content: ''; display: table; }
```

 ### `game/game.component.ts`

 ```typescript
import { Component, computed, signal } from '@angular/core';
import { BoardComponent } from '../board/board.component';

@Component({
  selector: 'app-game',
  standalone: true,
  imports: [BoardComponent],
  templateUrl: './game.component.html',
  styleUrl: './game.component.css',
})
export class GameComponent {
  history = signal<(string | null)[][]>([Array(9).fill(null)]);
  currentMove = signal(0);

  currentSquares = computed(() => this.history()[this.currentMove()]);
  xIsNext = computed(() => this.currentMove() % 2 === 0);

  handlePlay(nextSquares: (string | null)[]) {
    const nextHistory = [
      ...this.history().slice(0, this.currentMove() + 1),
      nextSquares,
    ];
    this.history.set(nextHistory);
    this.currentMove.set(nextHistory.length - 1);
  }

  jumpTo(nextMove: number) {
    this.currentMove.set(nextMove);
  }
}
```

 ### `game/game.component.html`

 ```html
<div class="game">
  <div class="game-board">
    <app-board
      [xIsNext]="xIsNext()"
      [squares]="currentSquares()"
      (play)="handlePlay($event)">
    </app-board>
  </div>
  <div class="game-info">
    <ol>
      @for (move of history(); track $index; let i = $index) {
        <li>
          @if (i === currentMove()) {
            <span>You are at move #{{ i }}</span>
          } @else {
            <button (click)="jumpTo(i)">
              {{ i > 0 ? 'Go to move #' + i : 'Go to game start' }}
            </button>
          }
        </li>
      }
    </ol>
  </div>
</div>
```

 ### `game/game.component.css`

 ```css
.game { display: flex; flex-direction: row; }
.game-info { margin-left: 20px; }
```

 ### `app.component.ts`

 ```typescript
import { Component } from '@angular/core';
import { GameComponent } from './game/game.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [GameComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
})
export class AppComponent {}
```

 ### `app.component.html`

 ```html
<app-game></app-game>
```

 ---

 ## Angular ↔ React Concept Map

 If you're coming from the React tutorial, here's the quick translation table:

 | React | Angular |
| --- | --- |
| Function component | Class with`@Component`decorator, split across`.ts`/`.html`/`.css` |
| JSX | Separate`.html`template file |
| Props (`function Square({value})`) | `@Input()`properties |
| Callback prop (`onSquareClick`) | `@Output()`+`EventEmitter` |
| `useState` | `signal()` |
| `useMemo`/ derived state | `computed()` |
| Setting state (`setSquares(...)`) | `.set(...)`/`.update(...)`on a signal |
| `key`prop in`.map()` | `track`expression in`@for` |
| `{condition && <X/>}`/ ternary | `@if / @else`block |
| `array.map(...)`in JSX | `@for (item of items; track expr)` |
| Importing a component to use it | `imports: [...]`array in`@Component` |
| CSS Modules / styled-components | Per-component`.css`file, auto view-encapsulated |

 ---

 ## Next Steps

 From here, natural extensions (all of which mirror the React tutorial's "Wrapping Up" challenges) include:

 1. **Display the location (row, col) of each move** in the history list — you'll need to track more than just the squares array per history entry.
2. **Sort the move list ascending/descending** with a toggle.
3. **Highlight the three winning squares** once someone wins, by having `calculateWinner` also return the winning line.
4. **Show a "Draw" message** when all nine squares are filled and there's no winner.
5. **Extract `calculateWinner` into its own file** (e.g., `src/app/game-logic.ts`) and unit-test it directly, since it's a pure function with no Angular dependencies — a good first exercise in Angular testing with Jasmine/Karma or Jest.

 Each of these forces you to touch the state-lifting and immutability patterns again, which is exactly the point — they're the two ideas this whole tutorial (in either framework) is really about.