# Projects

## Twenty One
### Introduction
Twenty-One is a solo game, with rules similar to Blackjack, but simplified. The player and the dealer are given each two cards, with one card from the dealer being concealed. The goal of each participant is to draw cards to get as close to 21 without busting (i.e having a score greater than 21). At any point, the player can choose to draw or to stay (i.e stop drawing cards). If the player busts, it is an automatic win for the dealer. Then it is the dealer's turn: he reveals it's concealed card, and has to draw until its score is at least 17. The winner is the one who gets closer to 21, and if both players have the same score, it is a draw.

Each card has the value of the rank indicated, except for figure cards and Ace. The figure cards count as 10, and the Ace count as 10 or 1, depending on which one provides a total closest to 21 without going beyond.

### Implementation
Given the description of the problem, I came up with the following CRC cards:

![CRC for Twenty-One](./images/twenty_one_crc.png "CRC for Twenty One")

Given the fact the the participant had no responsibilities, and that I could accomplish everything I needed easily for the hand class with an Array, I decided to get rid of the `Hand` class, and put its responsibilities in `Participant` class. I later chose to add also subclasses of `Participant`: `Player` and `Dealer`, for clarity purposes. I also found unnecessary to provide custom classes for suits and ranks, and stuck with Strings.<br><br>

The most tricky part was to decide if the Ace card was of value 11 or 1. I first thought of comparing each combinations of values for the Aces. For example, if there are two Aces in the hand, they could be both of value 11, both of value 1, or one could be of value 11, and the other 1. I would then add the potential values of the Aces to the rest of the hand value, and determine which one would come closest, but below or equal 21.
I later found out that I could simply add 11 to the hand value without the aces, and then check if this potential value busted. If so, I would change the value of the ace to 1. 
In the end, I chose to assume that the ace had a value of 11. Then for each ace, if the hand value was busting, I would subtract 10 to the total value, effectively making the value of the Ace, 1.

## Tic Tac Toe
### Introduction
Tic Tac Toe is a 2-player game, played traditionnally on a 9x9 grid. Each player has a different token, and each one places them on the grid, in alternance. The goal of the game is to make a vertical, horizontal or diagonal line with the player's token. If the grid is full and no player succeeds, it is a draw.

For this game, I chose to only use 1 player, and make the other player the computer, as this would allow me to implement an IA.

This program only uses a console (for now), and not a web browser.

### Implementation



## File-based CMS
### Introduction
## Todo App
### Introduction
## Budget App
### Introduction
## Memory Game
### Introduction
The memory game is a game in which the goal is to find pair of cards with the same color. Cards are disposed in a grid, and at each round, the player can turn face-up a pair of cards. If the card colors' match, they stay face-up, otherwise they return face-down. Once every card has been matched, the game ends.
### Implementation
I decided to use Object-Oriented Programming for the logic portion of the app, using Javascript and jQuery. After using a spike to define the problem, I used the Grid, Card and Game classes. I considered using a Player class as well, but the idea was quickly abandoned considering there was only one player for this application.<br>
Here are the CRC cards:

![CRC for Memory Game](./images/memory_game_crc.png "CRC for Memory Game")

<br>
The implementation of the `Card` class was straightforward. I used numbers instead of colors when creating them inside the grid constructor, as it would allow changing the colors easily if needed to. Then I used a Card method to convert the number to an actual color.<br><br>
The first challenge I faced was to make the grid itself. I would push the cards inside an array, but they would not be shuffled, and there are not Array methods that would allow me to shuffle the elements easily. I could use the `Math.random() - 0.5` as the function of `Array.prototype.sort()`, but due to the way the sort function works, certain shuffle configurations would appear more often than others. The <b>Fisher-Yates shuffle</b> was appropriate for my needs.<br><br>

On the HTML side, I displayed the grid, with each element being a square. The user interaction would be to click on a square to reveal what color it is. <br>
So in the Game class, I implemented what would happen when a user clicked on a square. The first step was to display the card color when it was clicked. I used jQuery for modifying the CSS and changing the color of the square.
The next step was to compare the cards when two of them was clicked. I first added a property in `Card` to check if the card was clicked or not, and then I could check the Grid object to see whether two cards were clicked or not.<br><br>

Another challenge worth noting was that when the two cards didn't match, I had to display them for a certain amount of time, then hide them again, without giving the user the possibility to click another card in the meantime. The tricky part was the second one, because the function I used for displaying the cards was <i>asynchronous</i>, meaning that the user could still click other cards. It didn't break the application, but it was not what I intended. To resolve that, I used a property in the Game object, `lastClickDate`, which saved the time at which two cards were matched. Each time the user would click, I would also save the time into a local variable, `currentClickDate`. Then I simply had to make sure that the difference of time between `currentClickDate` and `lastClickDate` were beyond the time the cards were displayed in order to allow the click function to run.

### Further steps (not implemented yet)
- Being able to change the grid size. 
- Gaving the possibility to have more than one player. Each player could have its own grid, or both could use the same grid. In the latter case, after one player reveals a pair of matching cards, he will play the next round again. Otherwise, the round is played by another player.
- Displaying the number of rounds in real time.


