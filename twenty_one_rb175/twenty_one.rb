require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

require 'sysrandom/securerandom'
require 'erb'

require 'pry'

configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
end

helpers do
  def prompt(message)
    %(<p class="line-breaks">=> #{message.gsub('\n', '\n' + '&nbsp;' * 6)}</p>)
  end

  def results
    code = <<~HEREDOC
      <section class="results <%= @game.result.to_s.gsub('_', '-') %>"
        <%= prompt(@game.result_msg) %>
        <form action="/new_round" method="POST">
          <button type="submit">Play a new round</button>
        </form>
      </section>
    HEREDOC

    ERB.new(code).result(binding)
  end
end

module MessageFormatable
  private

  def joinor(array, delimiter = ', ', word = 'or')
    case array.size
    when 0 then ''
    when 1 then array.first.to_s
    when 2 then "#{array.first} #{word} #{array.last}"
    else
      array[0..-2].join(delimiter) + " #{word} #{array.last}"
    end
  end
end

class Participant
  include MessageFormatable

  attr_reader :hand

  def initialize
    @hand = []
  end

  def <<(card)
    @hand << card
  end

  def busted?
    total > Game::HAND_VALUE_LIMIT
  end

  def total
    total_int = @hand.map(&:value).sum

    if @hand.any?(&:ace?)
      nb_of_aces = @hand.select(&:ace?).size

      nb_of_aces.times do
        break unless total_int > Game::HAND_VALUE_LIMIT
        total_int -= 10
      end
    end

    total_int
  end

  def discard_hand
    @hand = []
  end
end

class Player < Participant
  def hand_msg
    "You have a #{joinor(hand, ', a ', 'and a')}.\n" \
    "Your hand value is #{total}."
  end
end

class Dealer < Participant
  def hand_msg
    "Dealer has a #{joinor(hand, ', a ', 'and a')}.\n" \
    "Dealer's hand value is #{total}."
  end

  def first_card_msg
    "Dealer has a #{hand.first}."
  end
end

class Deck
  include MessageFormatable

  attr_reader :reshuffled

  def initialize
    @deck = []
    shuffle!
    @reshuffled = false
  end

  def size
    @deck.size
  end

  def size_msg
    "There are #{size} remaining cards in the deck."
  end

  def deal(participant)
    @reshuffled = false
    if empty?
      shuffle!
      @reshuffled = true
    end
    participant << @deck.shift
  end

  def shuffle!
    Card::SUITS.each do |suit|
      Card::RANKS.each do |rank|
        @deck << Card.new(suit, rank)
      end
    end
    @deck.shuffle!
  end

  def empty?
    @deck.empty?
  end
end

class Card
  SUITS = %w(hearts diamonds clubs spades)
  RANKS = (2..10).map(&:to_s) + %w(J Q K A)

  def initialize(suit, rank)
    @suit = suit
    @rank = rank
  end

  def to_s
    "#{@rank} of #{@suit}"
  end

  def value
    return @rank.to_i if lower_rank?
    return 10 if higher_rank?
    return 11 if ace?
  end

  def lower_rank?
    (2..10).map(&:to_s).include?(@rank)
  end

  def higher_rank?
    %w(J Q K).include?(@rank)
  end

  def ace?
    @rank == 'A'
  end
end

class Game
  HAND_VALUE_LIMIT = 21
  DEALER_HIT_LIMIT = 17

  attr_reader :deck, :player, :dealer, :deck_reshuffled

  def initialize
    @deck = Deck.new
    @player = Player.new
    @dealer = Dealer.new
    @deck_reshuffled = false
  end

  def deal_cards
    @deck_reshuffled = false
    2.times do
      @deck.deal(@player)
      @deck_reshuffled = true if @deck.reshuffled == true
      @deck.deal(@dealer)
      @deck_reshuffled = true if @deck.reshuffled == true
    end
  end

  def show_initial_cards
    @player.display_hand
    @dealer.display_first_card
  end

  def player_hit
    @deck_reshuffled = false
    @deck.deal(@player)
    @deck_reshuffled = true if @deck.reshuffled == true
  end

  def dealer_hit
    @deck_reshuffled = false
    @deck.deal(@dealer)
    @deck_reshuffled = true if @deck.reshuffled == true
  end

  def end_dealer_turn?
    @dealer.busted? || @dealer.total >= DEALER_HIT_LIMIT
  end

  def result_msg
    case result
    when :dealer_win
      'Dealer won!'
    when :player_win
      'Player won!'
    when :tie
      "It's a tie!"
    end
  end

  def result
    return :dealer_win if @player.busted?
    return :player_win if @dealer.busted?
    return :dealer_win if @dealer.total > @player.total
    return :player_win if @player.total > @dealer.total
    :tie
  end

  def discard_hands
    @player.discard_hand
    @dealer.discard_hand
  end

  def starting_cards_dealt?
    @player.hand.size >= 2 && @dealer.hand.size >= 2
  end
end

before do
  session[:game] ||= Game.new
  @game = session[:game]
  @deck = @game.deck
  @player = @game.player
  @dealer = @game.dealer
end

after do
  # currently unnecessary because we use mutative methods
  # session[:game] = @game
end

def deal_cards
  @game.deal_cards
  session[:message] = "The deck has been reshuffled." if @game.deck_reshuffled
end

def player_hits_one_card
  @game.player_hit
  session[:message] = "The deck has been reshuffled." if @game.deck_reshuffled
end

def dealer_hits_one_card
  @game.dealer_hit
  session[:message] = "The deck has been reshuffled." if @game.deck_reshuffled
end

# Redirects to the correct page (used for get requests)
def redirect_to_correct_page
  current_path = env["PATH_INFO"]

  return if current_path == correct_page

  redirect(correct_page)

  # current_path == correct_page ? return : redirect(correct_page)
end

# Returns correct page
def correct_page
  return "/results" if @player.busted?

  if session[:player_turn_end]
    return "/results" if @game.end_dealer_turn?
    "/dealer_turn"
  elsif @game.starting_cards_dealt?
    "/player_turn"
  else
    "/"
  end
end

# Display the game start page
get "/" do
  redirect_to_correct_page
  erb :start
end

get "/player_turn" do
  redirect_to_correct_page
  erb :player_turn
end

get "/dealer_turn" do
  redirect_to_correct_page
  erb :dealer_turn
end

get "/results" do
  redirect_to_correct_page
  erb :results
end

post "/deal_cards" do
  deal_cards
  redirect "/player_turn"
end

post "/player/hit" do
  player_hits_one_card
  redirect "/results" if @player.busted?
  redirect "/player_turn"
end

post "/player/stay" do
  session[:player_turn_end] = true
  redirect "/results" if @game.end_dealer_turn?
  redirect "/dealer_turn"
end

post "/dealer/hit" do
  dealer_hits_one_card
  redirect "/results" if @game.end_dealer_turn?
  redirect "/dealer_turn"
end

post "/new_round" do
  session[:player_turn_end] = false
  @game.discard_hands
  deal_cards
  redirect "/player_turn"
end
