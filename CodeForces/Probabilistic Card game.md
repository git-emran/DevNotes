Alice and Bob have a deck of cards, which is initially empty. They play a game that lasts for 𝑚 rounds. In the 𝑖-th round, the following events occur:

- a card with the value 𝑎𝑖 is added to the deck (it is guaranteed that no card with this value was previously in the deck);
- if there are fewer than 3 cards in the deck, the round ends;
- otherwise, Alice chooses a card from the deck;
- then Bob chooses a card (knowing which card Alice chose; he cannot choose the same one);
- one more card is chosen from the remaining 𝑖−2 cards uniformly at random;
- at the end, all three chosen cards are returned to the deck.

Let 𝑎 be the value on Alice's card, 𝑏 be the value on Bob's card, and 𝑐 be the value on the randomly chosen card. Then Bob receives:

- 0 points if |𝑎−𝑐|≤|𝑏−𝑐| (where |𝑥| denotes the absolute value of 𝑥);
- 0 points if card 𝑐 is between cards 𝑎 and 𝑏 (i. e., 𝑎<𝑐<𝑏 or 𝑏<𝑐<𝑎);
- |𝑏−𝑐| points otherwise.

Alice's goal in each round is to minimize Bob's expected score, while Bob's goal is to maximize it. What will be the expected score for Bob in each round if both Alice and Bob play optimally? Print the expected score modulo 998244353.

Note that the players minimize or maximize the real value of the expected score, not the result taken modulo 998244353.

Input

The first line contains a single integer (3≤𝑚≤2⋅105) — the number of rounds.

The second line contains 𝑚 integers 𝑎1,𝑎2,…,𝑎𝑚 (1≤𝑎𝑖≤1012; all 𝑎𝑖 are distinct).

Output

Print 𝑚−2 integers: the 𝑖-th number should be equal to the expected score for Bob in the round 𝑖+2 with optimal play from both players modulo 998244353 (i. e., let the expected score be an irreducible fraction 𝑥𝑦; you need to output 𝑥⋅𝑦−1mod998244353, where 𝑦−1 is such a number that 𝑦⋅𝑦−1mod998244353=1).

Note that the players minimize or maximize the real value of the expected score, not the result taken modulo 998244353.