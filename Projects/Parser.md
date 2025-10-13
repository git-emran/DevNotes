# Building a CSV and JSON parser

### In Typescript, NodeJS

This project is about learning to parse CSV or JSON or anything for that matter. By the end of the project, it should easy enough to implement parser in a desired language.

We start by creating an `abstract class Parser` which has a protected data variable that contains empty string

So let's create a file called `Parser.ts`.

```ts
export abstract class Parser {
  protected data = "";
  public constructor(private path: string) {
    this.load();
  }

  private load() {
    const data = fs.readFileSync(this.path, "utf8");
    this.data = data;
  }

  abstract parse(): void;
}
```
