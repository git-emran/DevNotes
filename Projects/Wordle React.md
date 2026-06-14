Using Json Server
Making a wordle hook
Submitting Guesses
Checking and Formatting Guesses
Creating a game Grid
Showing Past Guesses
Animating Tiles p1
Animating Tiles p2
Making a Keypad
Coloring Used letters
Ending a Game
Making a Modal


#### Data We need to track
Solution
	5 letter string, for example drain
Guesses
	- An array of past guesses
	- each past guesses in an array of letter objects [{}, {}, {}, {}, {}]
	- each object represents a letter in the word i.e key:a, color: yellow
	- current guess 
	- Keypad letters
	- number of turns 


using json-server to simulate solutions data
 npx json-server ./data/db.json --port 3001


# Building a Wordle clone using React

In the popular [Wordle](https://www.nytimes.com/games/wordle/index.html) game, you must guess a five-letter word by typing on a keyboard. When you type the word, you get hints related to the word you’re guessing. There’re multiple hints you get while playing this game.

- Green Letter - if it’s correct and in the right position of an actual word.
- Yellow Letter - if it’s correct but not in the right position of an actual word.
- Gray Letter - if it does not exist in the actual word.


This is essentially what you’ll learn to build in this guide: we’ll construct a Wordle clone in React. All the animations will resemble the original Wordle game. You’ll get a different word to guess with each page refresh. You need to have some basic understanding of React to build this game.

## Setup

To set up the React project: Run `npx create-react-app wordle` command and then `npm start` to start the project. You’ll have only three files (`App.js`, `index.css`, and `index.js`) inside the `src` folder. Delete all the other files to keep the `src` folder clean. Add the following code in the remaining files of the `src` folder.

```js
//   src/App.js
function App() {
  return (
    <div className="App">
      <h1>WORDLE</h1>
    </div>
  );
}

export default App
```

```css
/* src/index.css*/
body {
  text-align: center;
  font-size: 1em;
  font-family: verdana;
  margin: 0;
}
h1 {
  font-size: 1.2em;
  padding: 20px 0;
  border-bottom: 1px solid #eee;
  margin: 0 0 30px 0;
  color: #333;
}
```

```
//   src/index.js

import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

## Use JSON Server

You need a list of words to begin building of Wordle game. You’ll randomly pick one of those words to start the game. We can fetch a word list from an external source. A JSON file is required to store our data. Just create a `db.json` file inside the `data folder` and put the following data in it.

```js
{
  "solutions": [
    {"id": 1, "word": "ninja"},
    {"id": 2, "word": "spade"},
    {"id": 3, "word": "pools"},
    {"id": 4, "word": "drive"},
    {"id": 5, "word": "relax"},
    {"id": 6, "word": "times"},
    {"id": 7, "word": "train"},
    {"id": 8, "word": "cores"},
    {"id": 9, "word": "pours"},
    {"id": 10, "word": "blame"},
    {"id": 11, "word": "banks"},
    {"id": 12, "word": "phone"},
    {"id": 13, "word": "bling"},
    {"id": 14, "word": "coins"},
    {"id": 15, "word": "hello"}
  ]
}
```

Install json-server using `npm i json-server` to fetch data inside React component. The json-server turns JSON data into API endpoints. Run json-server using the command `json-server ./data/db.json --port 3001`. It’ll provide the endpoint `http://localhost:3001/solutions` to access the above data. We’ll use the `useEffect()` hook to fetch data from json-server. Also, we need the `useState()` hook to store data from json-server. Now, the `App.js` file will look like this:

```js
//   src/App.js

import { useEffect, useState } from 'react'

function App() {
  const [solution, setSolution] = useState(null)

  useEffect(() => {
    fetch('http://localhost:3001/solutions')
      .then(res => res.json())
      .then(json => {
        // random int between 0 & 14
        const randomSolution = json[Math.floor(Math.random() * json.length)]
        setSolution(randomSolution.word)
      })
  }, [setSolution])

  return (
    <div className="App">
      <h1>Wordle</h1>
      {solution && <div>Solution is: {solution}</div>}
    </div>
  )
}
export default App
```

## Make a Wordle Hook

Now, you’ve to write game logic to track user guesses. You’ll use letter colorizing to check if the guess is correct. You need to make a custom Wordle hook to handle the game logic. We’ll use that hook to implement the functionality. In this way, we’ll keep the UI of the game separate from the logic. Create a `useWordle.js` file inside the `src/hooks` folder. Let’s add a skeleton logic in the `useWordle.js` file.

```js
// src/hooks/useWordle.js

import { useState } from 'react'

const useWordle = (solution) => {
  const [turn, setTurn] = useState(0) 
  const [currentGuess, setCurrentGuess] = useState('')
  const [guesses, setGuesses] = useState([]) // each guess is an array
  const [history, setHistory] = useState([]) // each guess is a string
  const [isCorrect, setIsCorrect] = useState(false)

  // format a guess into an array of letter objects 
  // e.g. [{key: 'a', color: 'yellow'}]
  const formatGuess = () => {
    
  }

  // add a new guess to the guesses state
  // update the isCorrect state if the guess is correct
  // add one to the turn state
  const addNewGuess = () => {

  }

  // handle keyup event & track current guess
  // if user presses enter, add the new guess
  const handleKeyup = () => {

  }

  return {turn, currentGuess, guesses, isCorrect, handleKeyup}
}

export default useWordle
```

## Track the Current Guess

You need to track the guess while the user submits the word. For this, we’ll use an event listener for every key press. We’ll build a new `Wordle` React component to set up this listener. We’ll also access the `useWordle()` hook inside the `Wordle` component.

```js
// src/components/Wordle.js

import React, { useEffect } from 'react'
import useWordle from '../hooks/useWordle'

export default function Wordle({ solution }) {
  const { currentGuess, handleKeyup } = useWordle(solution)

  useEffect(() => {
    window.addEventListener('keyup', handleKeyup)

    return () => window.removeEventListener('keyup', handleKeyup)
  }, [handleKeyup])

  return (
    <div>
      <div>Current Guess - {currentGuess}</div>
    </div>
  )
}
```

For every key press, `handleKeyup` function will get fired. So, you need to make sure only English letters get tracked. Also, backspace will delete the last letter from the current guess.

```js
const handleKeyup = ({ key }) => {
    if (key === 'Backspace') {
      setCurrentGuess(prev => prev.slice(0, -1))
      return
    }
    if (/^[A-Za-z]$/.test(key)) {
      if (currentGuess.length < 5) {
        setCurrentGuess(prev => prev + key)
      }
    }
  }
```

We’re going to add UI in the `Wordle` component. So, we need to update `App` component according to it.

```js
import Wordle from './components/Wordle'

return (
    <div className="App">
      <h1>Wordle (Lingo)</h1>
      {solution && <Wordle solution={solution} />}
    </div>
)
```

## Submit and Format the Guesses

When a user submits the word by pressing `Enter`, we need to handle this word for further game logic. We’ll build the following logic:

- Only add a guess if the turn is less than five.
- Don’t allow duplicate words.
- Check word is five chars long.

Format guess functionality will compare each letter against the solution word and apply colors accordingly.

```js
const formatGuess = () => {
    let solutionArray = [...solution]
    let formattedGuess = [...currentGuess].map((l) => {
      return {key: l, color: 'grey'}
    })

    // find any green letters
    formattedGuess.forEach((l, i) => {
      if (solution[i] === l.key) {
        formattedGuess[i].color = 'green'
        solutionArray[i] = null
      }
    })
    
    // find any yellow letters
    formattedGuess.forEach((l, i) => {
      if (solutionArray.includes(l.key) && l.color !== 'green') {
        formattedGuess[i].color = 'yellow'
        solutionArray[solutionArray.indexOf(l.key)] = null
      }
    })

    return formattedGuess
}
```

Also, you need to call `formatGuess()` inside `handleKeyup()` when the user presses `Enter`.

```js
const handleKeyup = ({ key }) => {
    if (key === 'Enter') {
      // only add guess if turn is less than 5
      if (turn > 5) {
        console.log('you used all your guesses!')
        return
      }
      // do not allow duplicate words
      if (history.includes(currentGuess)) {
        console.log('you already tried that word.')
        return
      }
      // check word is 5 chars
      if (currentGuess.length !== 5) {
        console.log('word must be 5 chars.')
        return
      }
      const formatted = formatGuess()
      console.log(formatted)
    }
    if (key === 'Backspace') {
      setCurrentGuess(prev => prev.slice(0, -1))
      return
    }
    if (/^[A-Za-z]$/.test(key)) {
      if (currentGuess.length < 5) {
        setCurrentGuess(prev => prev + key)
      }
    }
}

return {turn, currentGuess, guesses, isCorrect, handleKeyup}
```

## Add the New Guesses

Now, you’ve done guess tracking, guess submitting, and guess formatting. You must add a formatted guess in the guesses array of the `useState()` hook. After that, we’ll print these guesses onto the Wordle grid. In the `handleKeyup` method, we need to call `addNewGuess()` after `formatGuess()`.

```js
  const formatted = formatGuess()
  addNewGuess(formatted)
```

We need a list of six guesses to print on the game grid. So, we’ve to set the guesses’ length to six in `useWordle.js`.

`const [guesses, setGuesses] = useState([...Array(6)])`

Let’s implement the `addNewGuess()` to update the guesses list for the Wordle grid.

```
const addNewGuess = (formattedGuess) => {
    if (currentGuess === solution) {
      setIsCorrect(true)
    }
    setGuesses(prevGuesses => {
      let newGuesses = [...prevGuesses]
      newGuesses[turn] = formattedGuess
      return newGuesses
    })
    setHistory(prevHistory => {
      return [...prevHistory, currentGuess]
    })
    setTurn(prevTurn => {
      return prevTurn + 1
    })
    setCurrentGuess('')
}
```

Also, we need all these values inside the `Wordle` component.  
`const { currentGuess, guesses, turn, isCorrect, handleKeyup } = useWordle(solution)`

## Create a Game Grid

Now, We’ve to display guesses on the Wordle grid. We’ll create a grid of six rows. Each row will consist of five squares for five letters. So, we’ll create two components, `Grid` and `Row`. Let’s create the `Grid` component first.

```js
// src/components/Grid.js

import React from 'react'
import Row from './Row'

export default function Grid({ guesses, currentGuess, turn }) {
  return (
    <div>
      {guesses.map((g, i) => {
        return <Row key={i} /> 
      })}
    </div>
  )
}
```

We must create a `Row` component for the `Grid` component.

```js
// src/components/Row.js

import React from 'react'

export default function Row() {

  return (
    <div className="row">
      <div></div>
      <div></div>
      <div></div>
      <div></div>
      <div></div>
    </div>
  )
  
}
```

Let’s add styles in the `index.css` file for the `Row` Component.

```css
.row {
  text-align: center;
  display: flex;
  justify-content: center;
}
.row > div {
  display: block;
  width: 60px;
  height: 60px;
  border: 1px solid #bbb;
  margin: 4px;
  text-align: center;
  line-height: 60px;
  text-transform: uppercase;
  font-weight: bold;
  font-size: 2.5em;
}
```

Finally, add the `Grid` component to the `Wordle` component.

```js
... 
import Grid from './Grid'
...
return (
    <div>
      ...
      <Grid guesses={guesses} currentGuess={currentGuess} turn={turn} />
    </div>
  )
```


## Show the Past and Current Guesses

At the moment, no letter is displayed on the grid. We’ll display the guesses’ list on this grid. First, we’ll pass each guess to `Row`. All letters of guess will get displayed on row squares. Every square will have a background color according to the guess. Let’s pass a guess to each row inside the `Grid` component.

```js
// src/components/Grid.js

export default function Grid({ guesses, currentGuess, turn }) {
  return (
    <div>
      {guesses.map((g, i) => {
        return <Row key={i} guess={g} /> 
      })}
    </div>
  )
}
```

Also, we need to adjust the logic of the Row component for the guesses display. Now the row component will look like this.

```js
// src/components/Row.js

import React from 'react'

export default function Row({ guess }) {

  if (guess) {
    return (
      <div className="row past">
        {guess.map((l, i) => (
          <div key={i} className={l.color}>{l.key}</div>
        ))}
      </div>
    )
  }

  return (
    <div className="row">
      <div></div>
      <div></div>
      <div></div>
      <div></div>
      <div></div>
    </div>
  )
  
}
```

Add the following styles for squares to the `index.css` file.

```css

.row > div.green {
  background: #5ac85a;
  border-color: #5ac85a;
}
.row > div.grey {
  background: #a1a1a1;
  border-color: #a1a1a1;
}
.row > div.yellow {
  background: #e2cc68;
  border-color: #e2cc68;
}

```

We’re displaying all the past guesses on the grid. We need to display the current guess while typing as well. In the `Grid` component, we want to pass the current guess to the `Row` component. So, the row with the current turn will display the current guess.

```js
// src/components/Grid.js

return (
    <div>
      {guesses.map((g, i) => {
        if (turn === i) {
          return <Row key={i} currentGuess={currentGuess} />
        }
        return <Row key={i} guess={g} /> 
      })}
    </div>
)
```

Now, update the logic of the `Row` component for the current guess. Also, extract the current guess as a prop in the `Row` component.

```js

// src/components/Row.js
if (currentGuess) {
    let letters = currentGuess.split('')

    return (
      <div className="row current">
        {letters.map((letter, i) => (
          <div key={i} className="filled">{letter}</div>
        ))}
        {[...Array(5 - letters.length)].map((_,i) => (
          <div key={i}></div>
        ))}
      </div>
    )
}
```

Now, we can display the current guess and past guesses.

## Tile Animations

There’re a few more things we need to do. First of all, we’ll handle animations for letters and words. We’ll do this through keyframe animations. We’ll not discuss animations in detail, as our focus is building a Wordle game using React. Let’s add animations to the `index.css` file.

```css
.row > div.green {
  --background: #5ac85a;
  --border-color: #5ac85a;
  animation: flip 0.5s ease forwards;
}
.row > div.grey {
  --background: #a1a1a1;
  --border-color: #a1a1a1;
  animation: flip 0.6s ease forwards;
}
.row > div.yellow {
  --background: #e2cc68;
  --border-color: #e2cc68;
  animation: flip 0.5s ease forwards;
}
.row > div:nth-child(2) {
  animation-delay: 0.2s;
}
.row > div:nth-child(3) {
  animation-delay: 0.4s;
}
.row > div:nth-child(4) {
  animation-delay: 0.6s;
}
.row > div:nth-child(5) {
  animation-delay: 0.8s;
}

/* keyframe animations */
@keyframes flip {
  0% {
    transform: rotateX(0);
    background: #fff;
    border-color: #333;
  }
  45% {
    transform: rotateX(90deg);
    background: white;
    border-color: #333;
  }
  55% {
    transform: rotateX(90deg);
    background: var(--background);
    border-color: var(--border-color);
  }
  100% {
    transform: rotateX(0deg);
    background: var(--background);
    border-color: var(--border-color);
    color: #eee;
  }
}
```

We also need to add a bounce effect to squares of the current guess. Let’s add this bounce animation to the `index.css` file.

```js
.row.current > div.filled {
  animation: bounce 0.2s ease-in-out forwards;
}

@keyframes bounce {
  0% { 
    transform: scale(1);
    border-color: #ddd;
  }
  50% { 
    transform: scale(1.2);
  }
  100% {
    transform: scale(1);
    border-color: #333;
  }
}
```

Now, We’re done with the animations part as well.

## Keypad Component

We’ve to build a little keypad to show the letters used and matched. It’s basically to visualize what letters we’ve used. Let’s first create letters data for the keypad.

```js
//  src/constants/keys.js

  const keys = [
    {key: "a"}, {key: "b"}, {key: "c"}, {key: "d"}, {key: "e"},
    {key: "f"}, {key: "g"}, {key: "h"}, {key: "i"}, {key: "j"},
    {key: "k"}, {key: "l"}, {key: "m"}, {key: "n"}, {key: "o"},
    {key: "p"}, {key: "q"}, {key: "r"}, {key: "s"}, {key: "t"},
    {key: "u"}, {key: "v"}, {key: "w"}, {key: "x"}, {key: "y"},
    {key: "z"},
  ];

export default keys;
```

Now, we’ve to create a `Keypad` component.

```js
//  src/components/Keypad.js

import React, { useState, useEffect } from 'react'

export default function Keypad({keys}) {
  const [letters, setLetters] = useState(null)

  useEffect(() => {
    setLetters(keys)
  }, [keys])

  return (
    <div className="keypad">
      {letters && letters.map(l => {
        return (
          <div key={l.key}>{l.key}</div>
        )
      })}
    </div>
  )
}
```

Let’s add styles to `index.css` for the `Keypad` component.

```css

.keypad {
  max-width: 500px;
  margin: 20px auto;
}
.keypad > div {
  margin: 5px;
  width: 40px;
  height: 50px;
  background: #eee;
  display: inline-block;
  border-radius: 6px;
  line-height: 50px;
}
```

Now, you need to add the `Keypad` component to the `Wordle` component.

```js
import Keypad from './Keypad'
import keys from '../constants/keys'

return (
    <div>
      ...
      <Keypad keys={keys}/>
    </div>
)
```

At the moment, the keypad’s not reflecting the keys used. We’ve to update it inside `useWordle.js`.

```js
// src/hooks/useWordle.js
const [usedKeys, setUsedKeys] = useState({}) 

const addNewGuess = (formattedGuess) => {
    if (currentGuess === solution) {
      setIsCorrect(true)
    }
    setGuesses(prevGuesses => {
      let newGuesses = [...prevGuesses]
      newGuesses[turn] = formattedGuess
      return newGuesses
    })
    setHistory(prevHistory => {
      return [...prevHistory, currentGuess]
    })
    setTurn(prevTurn => {
      return prevTurn + 1
    })
    setUsedKeys(prevUsedKeys => {
      formattedGuess.forEach(l => {
        const currentColor = prevUsedKeys[l.key]

        if (l.color === 'green') {
          prevUsedKeys[l.key] = 'green'
          return
        }
        if (l.color === 'yellow' && currentColor !== 'green') {
          prevUsedKeys[l.key] = 'yellow'
          return
        }
        if (l.color === 'grey' && currentColor !== ('green' || 'yellow')) {
          prevUsedKeys[l.key] = 'grey'
          return
        }
      })

      return prevUsedKeys
    })
    setCurrentGuess('')
}

  return {turn, currentGuess, guesses, isCorrect, usedKeys, handleKeyup}
```

Also, update the `Wordle` component.

```js
const { currentGuess, guesses, turn, isCorrect, usedKeys, handleKeyup } = useWordle(solution)

<Keypad keys={keys} usedKeys={usedKeys}/>
```

Now, handle the `usedKeys` prop inside the `Keypad` component and reflect used key colors on the keypad.

```js
export default function Keypad({ keys, usedKeys }) {
  return (
    <div className="keypad">
      {letters && letters.map(l => {
        const color = usedKeys[l.key]
        return (
          <div key={l.key} className={color}>{l.key}</div>
        )
      })}
    </div>
  )
}
```

We must add styles to `index.css` for the `Keypad` component.

```js
.keypad > div.green {
  background: #5ac85a;
  color: #fff;
  transition: all 0.3s ease-in;
}
.keypad > div.yellow {
  background: #e2cc68;
  color: #fff;
  transition: all 0.3s ease-in;
}
.keypad > div.grey {
  background: #a1a1a1;
  color: #fff;
  transition: all 0.3s ease-in;
}
```

Now, we’re done with the `Keypad` component.


## Showing a Modal

Finally, we need to detect when to end the game. We’ve to handle two scenarios:

- When the user guesses correctly.
- When the user runs out of turns.

For this, we’ll add an event listener inside the `useEffect()` hook of `Wordle` component.

```js
useEffect(() => {
    window.addEventListener('keyup', handleKeyup)

    if (isCorrect) {
      window.removeEventListener('keyup', handleKeyup)
    }
    if (turn > 5) {
      window.removeEventListener('keyup', handleKeyup)
    }

    return () => window.removeEventListener('keyup', handleKeyup)
  }, [handleKeyup, isCorrect, turn])
```

Now, we’ve to make a modal appear on the screen when the game ends. Let’s create a `Modal` component.

```js
// src/components/Modal.js

import React from 'react'

export default function Modal({ isCorrect, solution, turn }) {
  return (
    <div className="modal">
      {isCorrect && (
        <div>
          <h1>You Win!</h1>
          <p className="solution">{solution}</p>
          <p>You found the word in {turn} guesses</p>
        </div>
      )}
      {!isCorrect && (
        <div>
          <h1>Unlucky!</h1>
          <p className="solution">{solution}</p>
          <p>Better luck next time</p>
        </div>
      )}
    </div>
  )
}
```

Also, add styles to `index.css` for the `Modal` component.

```css
.modal {
  background: rgba(255,255,255,0.7);
  position: fixed;
  width: 100%;
  height: 100%;
  top: 0;
  left: 0;
}
.modal div {
  max-width: 480px;
  background: #fff;
  padding: 40px;
  border-radius: 10px;
  margin: 10% auto;
  box-shadow: 2px 2px 10px rgba(0,0,0,0.3);
}
.modal .solution {
  border: 1px solid MediumSeaGreen;
  color: #fff;
  background-color: MediumSeaGreen;
  font-weight: bold;
  font-size: 2.5rem;
  text-transform: uppercase;
  letter-spacing: 1px;
}
```

We need to add the `Modal` component inside the `Wordle` component.

```js
import React, { useState, useEffect } from 'react'

import Modal from './Modal'

const [showModal, setShowModal] = useState(false)

useEffect(() => {
    window.addEventListener('keyup', handleKeyup)

    if (isCorrect) {
      setTimeout(() => setShowModal(true), 2000)
      window.removeEventListener('keyup', handleKeyup)
    }
    if (turn > 5) {
      setTimeout(() => setShowModal(true), 2000)
      window.removeEventListener('keyup', handleKeyup)
    }

    return () => window.removeEventListener('keyup', handleKeyup)
  }, [handleKeyup, isCorrect, turn])

  {showModal && <Modal isCorrect={isCorrect} turn={turn} solution={solution} />}
```


A modal will appear on the screen when the game ends.

You’re done creating a Wordle clone using React!


