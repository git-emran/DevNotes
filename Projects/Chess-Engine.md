# Chess Engine

This is a chess engine written in Python. It uses the Pygame library to display the board and the pieces.

The game is logic is divided into two parts. Game Engine and The game player activity.

## Game Engine

Let's start with the design of the board.

```Python

        self.board = [
            ["bR", "bN", "bB", "bQ", "bK", "bB", "bN", "bR"],
            ["bp", "bp", "bp", "bp", "bp", "bp", "bp", "bp"],
            ["--", "--", "--", "--", "--", "--", "--", "--"],
            ["--", "--", "--", "--", "--", "--", "--", "--"],
            ["--", "--", "--", "--", "--", "--", "--", "--"],
            ["--", "--", "--", "--", "--", "--", "--", "--"],
            ["wp", "wp", "wp", "wp", "wp", "wp", "wp", "wp"],
            ["wR", "wN", "wB", "wQ", "wK", "wB", "wN", "wR"],
        ]



```

Most easy way to draw the board is to loop over dictionary and draw the squares.

We can basically divide the game into [few] parts. Moving the pieces, User can't move twice in a turn, registering the moves, so far the basic chess rules.

#### Moving
