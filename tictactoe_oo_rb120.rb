module MessageFormatable
  private

  def prompt(message)
    puts "=> #{message}"
  end

  def joinor(array, delimiter = ', ', word = 'or')
    case array.size
    when 0 then ''
    when 1 then array.first.to_s
    when 2 then "#{array.first} #{word} #{array.last}"
    else
      array[0..-2].join(delimiter) + "#{delimiter}#{word} #{array.last}"
    end
  end
end

module Inputable
  include MessageFormatable

  REGEXP_STRICT_POS_INTEGER = /\A0*[1-9]([0-9])*\z/
  REGEXP_POS_INTEGER = /\A([0-9])+\z/

  private

  def possible_choices(list, str)
    possible_list = []
    list.each do |elt|
      possible_list << elt if elt.match(/\A#{Regexp.quote(str)}/)
    end
    possible_list
  end

  def input_formatted
    gets.chomp.downcase.strip
  end

  def input_yes_no(message)
    message = message.strip
    answer = ''

    loop do
      prompt "#{message} (y/n)"
      answer = input_formatted
      break if ['y', 'n', 'yes', 'no'].include?(answer)
      prompt "Sorry, must be y or n"
    end
    answer[0]
  end

  def input_regexp_condition(regexp, msg)
    loop do
      prompt(msg)
      str = gets.chomp.strip

      return str if str.match(regexp)
      prompt("Sorry, invalid input.")
    end
  end

  def input_positive_int(msg)
    input_regexp_condition(REGEXP_POS_INTEGER, msg).to_i
  end

  def input_strict_positive_int(msg)
    input_regexp_condition(REGEXP_STRICT_POS_INTEGER, msg).to_i
  end

  def input_choice(arr, choice_msg = "Please choose",
                   display_choices: true, downcase_input: true)

    choice_msg = "#{choice_msg.strip} #{joinor(arr)}" if display_choices

    loop do
      prompt(choice_msg)
      str = downcase_input ? input_formatted : gets.chomp.strip
      return str if arr.include?(str)

      list_possibles = possible_choices(arr, str)
      return list_possibles.first if list_possibles.size == 1
      display_error_input_choice(arr.size, list_possibles)
    end
  end

  def display_error_input_choice(nb_of_choices, list_possibles)
    case list_possibles.size
    when 0, nb_of_choices then prompt("Sorry, invalid choice.")
    else prompt("Do you mean #{joinor(list_possibles)}?")
    end
  end
end

module SquareGridLinable
  def nb_of_squares
    square_grid_dim**2
  end

  def line_keys_arr
    horizontal_line_keys_arr +
      vertical_line_keys_arr +
      diagonal_line_keys_arr
  end

  def center_square_keys_arr
    return grid_one_center_square_key_arr if square_grid_dim.odd?
    grid_four_center_square_keys_arr
  end

  def grid_one_center_square_key_arr
    [(nb_of_squares / 2) + self.class::BEGINNING_INDEX]
  end

  def grid_four_center_square_keys_arr
    beginning_index1 = ((nb_of_squares - square_grid_dim) / 2) +
                       self.class::BEGINNING_INDEX - 1
    beginning_index2 = ((nb_of_squares + square_grid_dim) / 2) +
                       self.class::BEGINNING_INDEX - 1
    [beginning_index1, beginning_index1 + 1,
     beginning_index2, beginning_index2 + 1]
  end

  def horizontal_line_keys_arr
    index_sq = self.class::BEGINNING_INDEX
    horizontal_line_keys = []
    square_grid_dim.times do
      horizontal_line_keys << (index_sq..index_sq + square_grid_dim - 1).to_a
      index_sq += square_grid_dim
    end

    horizontal_line_keys
  end

  def vertical_line_keys_arr
    horizontal_line_keys_arr.first.zip(*horizontal_line_keys_arr[1..-1])
  end

  def diagonal_line_keys_arr
    [diagonal_keys_left_to_right, diagonal_keys_right_to_left]
  end

  def diagonal_keys_left_to_right
    index_arr = 0
    keys = []

    horizontal_line_keys_arr.each do |horizontal_line|
      keys << horizontal_line[index_arr]
      index_arr += 1
    end

    keys
  end

  def diagonal_keys_right_to_left
    index_arr = square_grid_dim - 1
    keys = []

    horizontal_line_keys_arr.each do |horizontal_line|
      keys << horizontal_line[index_arr]
      index_arr -= 1
    end

    keys
  end
end

module SquareGridDisplayable
  def nb_of_squares
    square_grid_dim**2
  end

  def draw
    index_square = self.class::BEGINNING_INDEX
    square_grid_dim.times do
      display_square_line(index_square)
      index_square += square_grid_dim
    end
  end

  private

  def square_length
    nb_of_squares.to_s.length + 3
  end

  def display_square_nb_line(index)
    (square_grid_dim - 1).times do
      index_indicator_line = "[#{index}]".ljust(square_length)

      print index_indicator_line + '|'
      index += 1
    end
    index_indicator_line = "[#{index}]".ljust(square_length)
    puts index_indicator_line
  end

  def display_empty_line
    puts (''.center(square_length) + '|') * (square_grid_dim - 1)
  end

  def display_line_with_marker(index)
    (square_grid_dim - 1).times do
      marker_line = self[index].center(square_length)
      print marker_line + '|'
      index += 1
    end
    marker_line = self[index].center(square_length)
    puts marker_line
  end

  def display_separating_line
    puts(('-' * square_length + "+") * (square_grid_dim - 1) +
         ('-' * square_length))
  end

  def display_square_line(index)
    last_line = (index >= horizontal_line_keys_arr.last.first)

    display_square_nb_line(index)
    display_line_with_marker(index)
    display_empty_line
    display_separating_line unless last_line
  end
end

class Board
  include SquareGridLinable
  include SquareGridDisplayable

  BEGINNING_INDEX = 1

  def deep_dup
    board_dup = dup

    duplicate_squares = @squares.dup.transform_values do |sq|
      sq = sq.dup
      sq.marker = sq.marker.dup

      sq
    end

    board_dup.squares = duplicate_squares
    board_dup
  end

  def initialize(sq_per_side)
    @squares = {}
    @squares_per_side = sq_per_side
    reset
  end

  def winning_lines
    line_keys_arr
  end

  def []=(key, marker)
    @squares[key].marker = marker
  end

  def unmarked_keys(squares_hsh = @squares)
    squares_hsh.keys.select { |key| squares_hsh[key].unmarked? }
  end

  def unmarked_center_keys
    center_square_keys_arr.select do |center_sq_key|
      unmarked_keys.include?(center_sq_key)
    end
  end

  def full?
    unmarked_keys.empty?
  end

  def someone_won?
    !!winning_marker
  end

  def almost_winning_square_keys(marker)
    keys = []
    winning_lines.each do |keys_line|
      squares = keys_line.map { |key| @squares[key] }
      squares_hsh = keys_line.zip(squares).to_h

      if (count_marker(squares_hsh, marker) == @squares_per_side - 1) &&
         squares.any?(&:unmarked?)
        keys << unmarked_keys(squares_hsh).first
      end
    end

    keys
  end

  def winning_marker
    winning_lines.each do |keys_line|
      squares = @squares.values_at(*keys_line)
      if identical_markers?(squares)
        return squares.first.marker
      end
    end

    nil
  end

  def reset
    (BEGINNING_INDEX..nb_of_squares - 1 + BEGINNING_INDEX).each do |key|
      @squares[key] = Square.new
    end
  end

  protected

  attr_writer :squares

  private

  def identical_markers?(squares)
    markers = squares.select(&:marked?).collect(&:marker)
    return false if markers.size != @squares_per_side
    markers.uniq.size == 1
  end

  def square_grid_dim
    @squares_per_side
  end

  def [](key)
    @squares[key].marker
  end

  def count_marker(squares_hsh, marker)
    squares_markers = squares_hsh.values.collect(&:marker)
    squares_markers.count(marker)
  end
end

class Square
  INITIAL_MARKER = " "
  attr_accessor :marker

  def initialize(marker=INITIAL_MARKER)
    @marker = marker
  end

  def unmarked?
    marker == INITIAL_MARKER
  end

  def marked?
    marker != INITIAL_MARKER
  end
end

class Player
  include Inputable

  attr_reader :score, :name
  attr_accessor :marker

  def initialize(name, marker)
    @name = name
    @marker = marker
    @score = 0
  end

  def add_one_point
    @score += 1
  end

  def reset_score
    @score = 0
  end

  def to_s
    "#{name} (#{marker})"
  end

  def input_and_set_name
    input_msg = "Choose a name for #{name}"
    new_name = input_regexp_condition(/\A\S+(.*\S+)*\z/, input_msg)
    @name = new_name
  end

  def input_and_set_marker(forbidden_markers)
    new_marker = nil
    input_msg = "Choose a marker for #{name}"
    loop do
      new_marker = input_regexp_condition(/\A\S\z/, input_msg)
      break unless forbidden_markers.include?(new_marker)
      prompt "Sorry, the marker is already taken"
    end

    self.marker = new_marker
  end
end

class TTTGame
  include Inputable

  CLASSIC_MARKERS = ['X', 'O']
  SCORE_LIMIT = 3

  MINIMAX = true
  MINIMAX_VAL_WIN = 1
  MINIMAX_VAL_LOSS = -1
  MINIMAX_VAL_TIE = 0

  def initialize
    @board = nil
    @humans = []
    @computers = []
    @player_order = []
    @first_player = nil
    @current_player = nil
  end

  def play
    clear
    display_welcome_message
    main_game
    display_goodbye_message
  end

  private

  attr_reader :board, :human, :computer

  def main_game
    choose_board_size
    add_players
    loop do
      choose_order
      play_tournament
      display_tournament_winner
      break unless play_again?
      reset_tournament
      display_play_again_message
    end
  end

  def play_tournament
    loop do
      display_board
      player_move
      display_result
      break if tournament_winner?
      display_next_round_message
      reset_round
    end
  end

  def player_move
    loop do
      current_player_moves
      break if board.someone_won? || board.full?
      if human_turn?
        clear_screen_and_display_board
      elsif @humans.empty?
        clear_screen_and_display_board
        display_next_move_message
      end
    end
  end

  def current_player_moves
    if human_turn?
      human_moves
    else
      computer_moves(minimax: MINIMAX)
    end
    switch_player
  end

  def player_markers
    (@humans + @computers).map(&:marker)
  end

  def marker_taken?(marker)
    player_markers.include?(marker)
  end

  def input_nb_humans_and_computers
    nb_humans = nil
    nb_computers = nil
    loop do
      nb_humans = input_positive_int("Choose the number of humans")
      nb_computers = input_positive_int("Choose the number of computers")

      break if nb_humans + nb_computers > 1
      prompt("You need at least 2 players to play!")
    end

    [nb_humans, nb_computers]
  end

  def add_humans(nb_humans, default_param)
    1.upto(nb_humans) do |nb|
      marker = default_param ? random_new_marker : nil
      @humans << Player.new("Human #{nb}", marker)
    end

    return if default_param

    @humans.each do |human|
      human.input_and_set_name
      human.input_and_set_marker(player_markers)
    end

    nil
  end

  def add_computers(nb_computers, default_param)
    1.upto(nb_computers) do |nb|
      marker = default_param ? random_new_marker : nil
      @computers << Player.new("Computer #{nb}", marker)
    end

    return if default_param
    @computers.each do |computer|
      computer.input_and_set_name
      computer.marker = random_new_marker
    end

    nil
  end

  def add_players
    nb_humans, nb_computers = input_nb_humans_and_computers

    case input_yes_no("Do you want to use default names and markers?")
    when 'y' then default_param = true
    when 'n' then default_param = false
    end

    add_humans(nb_humans, default_param)
    add_computers(nb_computers, default_param)
  end

  def random_new_marker
    priority_markers = CLASSIC_MARKERS - player_markers
    upcase_markers = ('A'..'Z').to_a - player_markers

    # rubocop: disable Style/EmptyCaseCondition
    new_marker = case
                 when !priority_markers.empty? then priority_markers.sample
                 when !upcase_markers.empty?   then upcase_markers.sample
                 else find_double_digit_marker
                 end
    # rubocop: enable Style/EmptyCaseCondition

    new_marker
  end

  def find_double_digit_marker
    marker_test = 'AA'
    while player_markers.include?(marker_test)
      marker_test.next!
    end

    marker_test
  end

  def display_welcome_message
    prompt "Welcome to Tic Tac Toe"
    puts ""
  end

  def display_goodbye_message
    prompt "Thanks for playing Tic Tac Toe! Goodbye!"
  end

  def display_board
    prompt <<~MSG
      Humans: #{joinor(@humans.map(&:to_s), ', ', 'and')}
         Computers: #{joinor(@computers.map(&:to_s), ', ', 'and')}
    MSG

    puts ""
    board.draw
    puts ""
  end

  def clear_screen_and_display_board
    clear
    display_board
  end

  def choose_order
    @player_order = case input_choice(['humans', 'computers', 'random'],
                                      "Choose who goes first:")
                    when 'humans'    then @humans + @computers
                    when 'computers' then @computers + @humans
                    when 'random'    then (@humans + @computers).shuffle
                    end

    @first_player = @player_order.first
    @current_player = @first_player
  end

  def choose_board_size
    input_msg = "How many squares do you want per side?"
    board_dim = input_strict_positive_int(input_msg)
    @board = Board.new(board_dim.to_i)
  end

  def tournament_winner?
    !!tournament_winner
  end

  def tournament_winner
    @player_order.each do |player|
      return player if player.score == SCORE_LIMIT
    end
    nil
  end

  def display_tournament_winner
    prompt "#{tournament_winner} won the tournament!"
  end

  def human_moves
    prompt "next players: #{next_players_str}"

    input_msg = "#{@current_player}, choose a square:"
    choices = board.unmarked_keys.map(&:to_s)
    square = input_choice(choices, input_msg).to_i

    board[square] = @current_player.marker
  end

  def computer_moves(minimax: false)
    chosen_square_key = if minimax
                          minimax_key_choices.sample
                        else
                          offense_defense_key_choice
                        end

    board[chosen_square_key] = @current_player.marker
  end

  def offense_defense_key_choice
    offense_keys = offense_key_choices
    defense_keys = defense_key_choices
    center_keys = board.unmarked_center_keys

    # rubocop: disable Style/EmptyCaseCondition
    case
    when !offense_keys.empty? then offense_keys.sample
    when !defense_keys.empty? then defense_keys.sample
    when !center_keys.empty? then center_keys.sample
    else board.unmarked_keys.sample
    end
    # rubocop: enable Style/EmptyCaseCondition
  end

  def minimax_key_choices
    minimax_results = Hash.new { |hash, key| hash[key] = [] }

    board.unmarked_keys.each do |key|
      minimax_results[minimax_value(key)] << key
    end

    minimax_results[minimax_results.keys.max]
  end

  def offense_key_choices
    board.almost_winning_square_keys(@current_player.marker)
  end

  def defense_key_choices
    next_players_order.each do |player|
      unless board.almost_winning_square_keys(player.marker).empty?
        return board.almost_winning_square_keys(player.marker)
      end
    end

    []
  end

  def hypotethical_move_game_state(board, square_key, player_turn)
    new_board = board.deep_dup
    new_board[square_key] = player_turn.marker
    player_turn = next_player(player_turn)

    [new_board, player_turn]
  end

  def minimax_endgame_value(board)
    maximizer_player = @current_player
    return nil unless board.someone_won? || board.full?

    case board.winning_marker
    when maximizer_player.marker then MINIMAX_VAL_WIN
    when nil then MINIMAX_VAL_TIE
    else MINIMAX_VAL_LOSS
    end
  end

  def minimax_value(square_key,
                    player_turn = @current_player,
                    board = @board)
    maximizer_player = @current_player

    new_board, player_turn =
      hypotethical_move_game_state(board, square_key, player_turn)

    final_value = minimax_endgame_value(new_board)
    return final_value if final_value

    values = []
    new_board.unmarked_keys.each do |key|
      values << minimax_value(key, player_turn, new_board)
    end

    player_turn == maximizer_player ? values.max : values.min
  end

  def find_player(marker)
    @player_order.each do |player|
      return player if player.marker == marker
    end

    nil
  end

  def display_result
    display_board

    winning_player = nil

    if board.someone_won?
      winning_player = find_player(board.winning_marker)
      winning_player.add_one_point
    end

    prompt(winning_player ? "#{winning_player} won!" : "It's a tie!")
    puts
    prompt score_str
  end

  def score_str
    humans_score_str = 'Humans: '
    @humans.each do |human|
      humans_score_str << "#{human.score} points for #{human.name}. "
    end
    computers_score_str = 'Computers: '
    @computers.each do |computer|
      computers_score_str << "#{computer.score} points for #{computer.name}. "
    end

    <<~MSG
      #{humans_score_str}
         #{computers_score_str}
    MSG
  end

  def play_again?
    input_yes_no("Would you like to play again?") == 'y'
  end

  def human_turn?
    @humans.include?(@current_player)
  end

  def next_player(player = @current_player)
    @player_order.each.with_index do |player_compared, index|
      if player_compared == player
        return @player_order.first if index == @player_order.size - 1
        return @player_order[index + 1]
      end
    end
  end

  def next_players_order
    next_players = @player_order.dup

    unless @player_order.first == next_player
      next_players.rotate!
    end

    next_players - @player_order.select { |player| player == @current_player }
  end

  def next_players_str
    joinor(next_players_order, ', ', '')
  end

  def switch_player
    @current_player = next_player
  end

  def clear
    system 'clear'
  end

  def reset_round
    board.reset
    @first_player = next_player(@first_player)
    @current_player = @first_player
    clear
  end

  def reset_tournament
    reset_round
    @player_order.each(&:reset_score)
  end

  def display_play_again_message
    prompt "Let's play again!"
    puts ""
  end

  def display_next_round_message
    prompt "Press enter to play the next round"
    gets.chomp
  end

  def display_next_move_message
    prompt "Press enter for #{@current_player} to play"
    gets.chomp
  end
end

game = TTTGame.new
game.play
