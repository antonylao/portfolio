const Delayable = {
  //works asynchronously
  delay(milliseconds){
    return new Promise(resolve => {
        setTimeout(resolve, milliseconds);
    });
  }
}

class Grid {
  constructor(rows, columns) {
    this.grid = {};
    this.nbCards = rows * columns;

    if (this.nbCards % 2 !== 0) {
      console.error("The grid does not work for memory game because it has and odd number of cards")
    }

    this.fillGrid()
    this.shuffle()
    // console.log(this.grid)
  }

  cardsClicked() {
    const cards = []
    for (let i=1; i<=this.nbCards; i++) {
      let currentCard = this.grid[i]
      if (currentCard.clicked) {cards.push({card: currentCard, position: i})}
    }
    return cards;
  }

  nbCardsClicked() {
    return this.cardsClicked().length
  }

  isComplete() {
    let completed = false;

    for (let i=1; i<=this.nbCards; i++) {
      if (this.grid[i].isFaceUp() === false) {
        break
      } 

      if (i === this.nbCards && this.grid[i].isFaceUp() === true) {
        completed = true;
      } 
    }
    return completed;
  }

  /*private methods */

  fillGrid() {
    let cardValue = 1;
    for (let i=1; i<=this.nbCards; i++) {
      this.grid[i] = (new Card(cardValue))
      if (i % 2 === 0) {
        cardValue++;
      }
    }
  }

  shuffle() {
    let grid = this.grid
    for (let i = this.nbCards; i > 1; i--) {
      let j = Math.floor((Math.random() * i) + 1); // random index from (0 to i -1) + 1 = 1 to i
      [grid[i], grid[j]] = [grid[j], grid[i]];
    }
  }
}

class Card {
  static faceDownColor = 'grey';

  static compareCards(card1, card2) {
    let card1Value = card1.value;
    let card2Value = card2.value;

    if (card1Value === card2Value) {
      console.log("Yes! Both of the cards have the same value!")
      return true
    }

    return false;
  }

  static color(cardValue) {
    const colors = ['red', 'blue', 'yellow', 'green', 'magenta', 'teal', 'pink', 'cyan']
    return colors[cardValue - 1];
  }

  constructor(value) {
    this._faceUp = false;
    this.clicked = false;
    this._value = value;
    this.color = Card.color(value)
  }

  isFaceUp() {
    return this._faceUp
  }

  isFaceDown() {
    return !this.isFaceUp()
  }

  turnFaceUp() {
    this._faceUp = true;
    this.clicked = true;
  }

  turnFaceDown() {
    this._faceUp = false;
    this.clicked = false;
  }

  get value() {
    if (this.isFaceUp()) {
      return this._value;
    } else {
      return null;
    }
  }

  get position() {
    return this._position
  }
}

class Game {
  static freezeTime = 500;
  static nbRows = 4
  static nbColumns = 4

  constructor() {
    this.gridObj = new Grid(Game.nbRows, Game.nbColumns)
    this.lastClickDate = 0;
    this.nbRounds = 0;

    //set background color of cards to grey (not sure if correct place to do that)
    $(".card").css("background-color", Card.faceDownColor)
  }

  displayResults() {
    alert(`Congratulations! You finished the game in ${this.nbRounds} rounds!`)
  }

  onCardClicked(id) {
    let currentClickDate = Date.now()
  
    //do not run the function while displaying pair of cards that do not match
    if (currentClickDate - this.lastClickDate < Game.freezeTime) {
      return;
    }
  
    let card = this.gridObj.grid[id]
    if (card.isFaceDown()) {
      card.turnFaceUp();
      $('#' + id).css('background-color', card.color)
  
      console.log(this.gridObj)
      console.log(id)
    }
  
    if (this.gridObj.nbCardsClicked() === 2) {
      this.nbRounds++;
      const cards = this.gridObj.cardsClicked();
      let card1 = cards[0]['card']
      let card2 = cards[1]['card']
      let card1Pos = cards[0]['position']
      let card2Pos = cards[1]['position']
  
      if (!Card.compareCards(card1, card2)) {
        this.lastClickDate = Date.now()
        card1.turnFaceDown();
        card2.turnFaceDown();
  
        async function hideClickedCards() {
          await Delayable.delay(Game.freezeTime)
          $('#' + card1Pos).css('background-color', Card.faceDownColor)
          $('#' + card2Pos).css('background-color', Card.faceDownColor)
        }
        hideClickedCards()
        
  
      } else {
        card1.clicked = false;
        card2.clicked = false;
        
  
        if (this.gridObj.isComplete()) {
          this.displayResults()
        }
      }
    }
  }
}

const game = new Game;
