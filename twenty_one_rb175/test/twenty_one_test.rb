ENV["RACK_ENV"] = "test" 

require "minitest/autorun"
require "rack/test" 

require_relative "../twenty_one"

class Game
  attr_writer :deck # `attr_reader :deck` is already in the original class
end

class Deck
  attr_accessor :deck
end

class Card
  attr_reader :rank, :suit

  def ==(other)
    self.rank == other.rank && self.suit == other.suit
  end
end

class TwentyOneTest < Minitest::Test
  include Rack::Test::Methods

  LAST_RESPONSE_LOCATION_HOST = "http://example.org"

  def app
    Sinatra::Application
  end

  # Access the session hash
  def session
    last_request.env["rack.session"]
  end

  def setup
  end

  def teardown
  end

  def deck_top_card
    session[:game].deck.deck.first
  end

  def test_start_page
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, '<button type="submit"'
    assert_includes last_response.body, "Start Game"
  end

  def test_deal_cards
    get "/" # initialize the session[:game] var
    # NB: session method here returns a different object than session in the main app!
    # => you can't mutate session in the main app
    first_card, second_card, third_card, fourth_card = session[:game].deck.deck[0, 4]

    post "/deal_cards"
    game = session[:game]
    player = game.player
    dealer = game.dealer

    assert_equal 302, last_response.status
    assert_equal player.hand, [first_card, third_card]
    assert_equal dealer.hand, [second_card, fourth_card]
  end
  
  def test_player_turn_page
    get "/" # initialize the session[:game] var
    first_card, second_card, third_card, fourth_card = session[:game].deck.deck[0, 4]
    
    post "/deal_cards"
    game = session[:game]
    player = game.player
    dealer = game.dealer
    player_hand_value = player.total

    get "/player_turn"
    assert_includes last_response.body, "Dealer has a #{second_card.rank} of #{second_card.suit}."
    assert_includes last_response.body, "You have a #{first_card.rank} of #{first_card.suit} and a #{third_card.rank} of #{third_card.suit}."
    assert_includes last_response.body, "Your hand value is #{player_hand_value}."
    assert_includes last_response.body, "Please choose if you want to 'hit' or 'stay'."
    assert_includes last_response.body, '<button type="submit"'

    next_card = deck_top_card

    post "/player/hit"

    # if player busted, 'get "/player_turn" will redirect to "/results"'
    unless session[:game].player.busted?
      get "/player_turn"
      assert_includes last_response.body, "You have a #{first_card.rank} of #{first_card.suit}, a #{third_card.rank} of #{third_card.suit} and a #{next_card.rank} of #{next_card.suit}."
    end
  end

  # NB: POST requests are done without any checks
  def test_player_hit
    post "/deal_cards"

    next_card = deck_top_card
    
    post "/player/hit"
    assert_equal 302, last_response.status
    assert_includes session[:game].player.hand, next_card
    assert_equal false, !!session[:player_turn_end]
  end

  def test_player_stays
    post "/deal_cards"
    post "/player/stay"
    assert_equal 302, last_response.status
    assert_equal session[:game].player.hand.size, 2
    assert_equal true, session[:player_turn_end]
  end

  def test_dealer_hit
    post "/deal_cards"
    post "/player/stay"

  
    next_card = deck_top_card
    post "/dealer/hit"
    assert_equal 302, last_response.status
    assert_includes session[:game].dealer.hand, next_card
  end

  def test_dealer_turn_page
    get "/"
    first_card, second_card, third_card, fourth_card = session[:game].deck.deck[0, 4]

    post "/deal_cards"
    post "/player/stay"

    game = session[:game]
    player = game.player
    dealer = game.dealer
    player_hand_value = player.total
    dealer_hand_value = dealer.total

    unless game.end_dealer_turn?
      get "/dealer_turn"
      assert_equal 200, last_response.status
      assert_includes last_response.body, "Dealer has a #{second_card.rank} of #{second_card.suit} and a #{fourth_card.rank} of #{fourth_card.suit}."
      assert_includes last_response.body, "You have a #{first_card.rank} of #{first_card.suit} and a #{third_card.rank} of #{third_card.suit}."
      assert_includes last_response.body, "Dealer's hand value is #{dealer_hand_value}."
      assert_includes last_response.body, "Your hand value is #{player_hand_value}."
      assert_includes last_response.body, '<button type="submit"'
      assert_includes last_response.body, "Click to reveal next card"
    end
  end

  
  def test_results_page
    post "/deal_cards"
    post "/player/stay"

    game = session[:game]
    while !game.end_dealer_turn?
      post "/dealer/hit"
      game = session[:game]
    end

    get "/results"
    assert_equal 200, last_response.status

    assert_includes last_response.body, '<button type="submit"'
    assert_includes last_response.body, "Play a new round"
  end


  def test_results_page_player_busted
    post "/deal_cards"

    game = session[:game]
    player = game.player
    while !player.busted?
      post "/player/hit"
      game = session[:game]
      player = game.player
    end

    get "/results"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "You have busted!"
  end

  def test_results_page_dealer_busted
    post "/deal_cards"
    post "/player/stay"
    
    game = session[:game]
    dealer = game.dealer
    while !dealer.busted?
      post "/dealer/hit"
      game = session[:game]
      dealer = game.dealer
    end

    get "/results"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "Dealer busted!"
  end

  def test_new_round
    post "/deal_cards"
    post "/player/stay"
    
    while !session[:game].end_dealer_turn?
      post "/dealer/hit"
    end

    post "/new_round"
    session[:player_turn_end] = false
    
    assert_equal 302, last_response.status

    game = session[:game]
    assert_equal 2, game.player.hand.size
    assert_equal 2, game.dealer.hand.size

    get "/player_turn"
    assert_equal 200, last_response.status
  end

  def test_reshuffle_deck_when_dealing_first_cards_1
    get "/"

    deck_initial_size = session[:game].deck.size
    nb_of_cards_dealt = 4
    (deck_initial_size / nb_of_cards_dealt).times do
      post "/deal_cards"
    end

    deck = session[:game].deck
    assert_equal deck.empty?, true

    post "/deal_cards"
    assert_equal "The deck has been reshuffled.", session[:message]
    deck = session[:game].deck
    assert_equal deck.size, (deck_initial_size - nb_of_cards_dealt)
  end

  def test_reshuffle_deck_when_dealing_first_cards_2
    get "/"

    deck_initial_size = session[:game].deck.size
    nb_of_cards_dealt = 4
    ((deck_initial_size / nb_of_cards_dealt) - 1).times do
      post "/deal_cards"
    end

    post "/player/hit"
    deck = session[:game].deck
    assert_equal deck.size, 3

    post "/deal_cards"
    assert_equal "The deck has been reshuffled.", session[:message]
    deck = session[:game].deck
    assert_equal deck.size, (deck_initial_size - 1)
  end

  def test_reshuffle_deck_when_player_hits_empty_deck
    get "/"

    deck_initial_size = session[:game].deck.size

    deck_initial_size.times do 
      post "/player/hit"
    end

    deck = session[:game].deck
    assert_equal deck.empty?, true

    post "/player/hit"
    assert_equal "The deck has been reshuffled.", session[:message]
    deck = session[:game].deck
    assert_equal deck.size, (deck_initial_size - 1)
  end

  def test_reshuffle_deck_when_dealer_hits_empty_deck
    get "/"

    deck_initial_size = session[:game].deck.size

    deck_initial_size.times do 
      post "/dealer/hit"
    end

    deck = session[:game].deck
    assert_equal deck.empty?, true

    post "/dealer/hit"
    assert_equal "The deck has been reshuffled.", session[:message]
    deck = session[:game].deck
    assert_equal deck.size, (deck_initial_size - 1)
  end

  def test_player_hit_redirect_to_player_turn_page_when_not_busted
    post "/deal_cards"
  
    player = session[:game].player
    while !player.busted?
      assert_equal 302, last_response.status
      assert_equal LAST_RESPONSE_LOCATION_HOST + "/player_turn", last_response["Location"]
      post "player/hit"
      player = session[:game].player
    end
  end

  def test_player_hit_and_bust_redirect_to_results_page
    post "/deal_cards"

    player = session[:game].player
    while !player.busted?
      post "/player/hit"
      player = session[:game].player
    end

    assert_equal 302, last_response.status
    assert_equal LAST_RESPONSE_LOCATION_HOST + "/results", last_response["Location"]
  end

  def test_player_stay_redirect_to_dealer_turn_page
    post "/deal_cards"
    post "/player/stay"

    # edge case when dealer has already more than Game::DEALER_HIT_LIMIT
    unless session[:game].end_dealer_turn?
      assert_equal 302, last_response.status
      assert_equal LAST_RESPONSE_LOCATION_HOST + "/dealer_turn", last_response["Location"]
    end
  end

  def test_dealer_hits_less_than_limit_redirect_to_dealer_turn_page
    post "/deal_cards"
    post "/player/stay"

    return if session[:game].end_dealer_turn?

    post "/dealer/hit"

    unless session[:game].end_dealer_turn?
      assert_equal 302, last_response.status
      assert_equal LAST_RESPONSE_LOCATION_HOST + "/dealer_turn", last_response["Location"]
    end
  end

  def test_dealer_hit_and_bust_redirect_to_results_page
    post "/deal_cards"
    post "/player/stay"

    while !session[:game].end_dealer_turn?
      post "/dealer/hit"
    end

    if session[:game].dealer.busted?
      assert_equal 302, last_response.status
      assert_equal LAST_RESPONSE_LOCATION_HOST + "/results", last_response["Location"]
    end
  end

  def test_dealer_hit_above_limit_redirect_to_results_page
    post "/deal_cards"
    post "/player/stay"

    return if session[:game].end_dealer_turn?

    while !session[:game].end_dealer_turn?
      post "/dealer/hit"
    end

    unless session[:game].dealer.busted?
      assert_equal 302, last_response.status
      assert_equal LAST_RESPONSE_LOCATION_HOST + "/results", last_response["Location"]
    end
  end

  def test_redirected_when_entering_wrong_url
    get "/results"
    assert_equal 302, last_response.status
    assert_equal LAST_RESPONSE_LOCATION_HOST + "/", last_response["Location"]

    post "/deal_cards"
    get "/"
    assert_equal 302, last_response.status
    assert_equal LAST_RESPONSE_LOCATION_HOST + "/player_turn", last_response["Location"]

    post "/player/stay"
    get "/player_turn"
    unless session[:game].end_dealer_turn?
      assert_equal 302, last_response.status
      assert_equal LAST_RESPONSE_LOCATION_HOST + "/dealer_turn", last_response["Location"]
    end

    while !session[:game].end_dealer_turn?
      post "/dealer/hit"
    end

    get "/dealer_turn"
    assert_equal 302, last_response.status
    assert_equal LAST_RESPONSE_LOCATION_HOST + "/results", last_response["Location"]

    post "/new_round"
    get "/results"
    assert_equal 302, last_response.status
    assert_equal LAST_RESPONSE_LOCATION_HOST + "/player_turn", last_response["Location"]
  end
end

