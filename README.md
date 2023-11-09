# Projects

## Twenty One
### Introduction
## Tic Tac Toe
### Introduction
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

### Further steps
- Being able to change the grid size.
- Gaving the possibility to have more than one player. Each player could have its own grid, or both could use the same grid. In the latter case, after one player reveals a pair of matching cards, he will play the next round again. Otherwise, the round is played by another player.
- Displaying the number of rounds in real time.


