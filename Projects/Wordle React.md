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
