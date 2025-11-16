# Min By

Implement a function minBy(array, iteratee) that finds the element inside array with the minimum value after going through iteratee.

#### Arguments

1. Array (Array): The array to iterate over.
2. Iteratee (Function): The iteratee invoked per element, which is a function that accepts one argument: (value).

#### Returns

(\*): Returns the minimum value.

#### Examples

    minBy([2, 3, 1, 4], (num) => num); // => 1
    minBy([{ n: 1 }, { n: 2 }], (o) => o.n); // => { n: 1 }

The function should ignore elements where iteratee produces null or undefined.

    minBy([{ n: 1 }, { n: 2 }], (o) => o.m); // => undefined

```js
export default function minBy(array, iteratee) {
  let minValue;
  let minElement;

  for (const item of array) {
    const value = itaratee(item);

    if (value === undefined) continue;
    if (minValue === undefined || value < minValue) {
      minValue = value;
      minElement = item;
    }
  }
  return minElement;
}
```
