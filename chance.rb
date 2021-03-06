require 'rubygems'
require 'net/http'
require 'open-uri'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
require 'blackjack1'
include ActionView::Helpers::DateHelper

require 'json'
class Hand 
  # The player
  attr_accessor :cards # The cards in the hand
  def self.deck=(deck)
    @deck = deck.cards.shuffle
  end 
  # Set which deck the game is using. Also shuffles the deck.
  def self.deck
    @deck
  end 
  # The deck the game is using
  def bust?; value > 21; end # Returns true if the value is greater than 21.
  def blackjack?; value == 21 && @cards.length == 2; end # Returns true if you have blackjack.
  def initialize(deck, cards=nil)
    @deck = deck
    @cards = (cards.nil? and !@deck.nil?) ? [@deck.shift, @deck.shift] : cards
  end
  def view
    @cards.each {|card| "#{card.abbr}\t"}
  end 
  # The view of the cards
  def hit
    @cards.push @deck.shift
  end 
  # Add a card to @cards from @deck
  def value 
    # The value of the cards in @cards
    v, aces = 0, 0
    @cards.each do |card|
      v += card.value
      aces += 1 if card.num == "Ace"
    end
    while v > 21 && aces > 0
      v -= 10
      aces -= 1
    end
    return v
  end
  def to_json(args={})
    self.cards.map do |c| 
      {
        "num" => c.num,
        "suit" => c.suit
      }  
    end.to_json(args)
  end
  def self.from_json(string, deck=nil)
    jh = JSON.parse(string)
    cds = jh.map do |c|
      CardDeck::Card.new c["num"], c["suit"]
    end
    return Hand.new(deck, cds)
  end
end

class Deck < CardDeck::Deck
  def initialize(args={jokers: false})
    return super(args) unless args[:raw_deck]
  end
  def to_json(args={})
    return self.cards.map do |c|
      {
        "num" => c.num,
        "suit" => c.suit
      }
    end.to_json(args)
  end
  def self.from_json(string)
    n_deck = Deck.new
    s_deck = JSON.parse(string)
    n_deck.cards = s_deck.map{|c| CardDeck::Card.new c["num"], c["suit"]}
    return n_deck
  end
  def stock(num, suit)
    @cards.push CardDeck::Card.new num, suit
  end 
  def shift
    @cards.shift
  end
  # Creates a Card to add to Deck#cards
end

class Chance
  ENDPOINT = "http://us.battle.net/api/sc2/profile/310150/1/Destiny/matches"
  VALID_WORDS = %w{hit stay stand bet purse show claim draw bj}
  MODS = %w{iliedaboutcake hephaestus 13hephaestus bot destiny ceneza sztanpet}.map{|m| m.downcase}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/chance/"
  STARTCASH = 100
  MINBLIND = 5
  WHISPER_SUFFIX = " Please click \'Mark as Read\' so that I can continue to send messages."

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
    @chatter = ""
  end
  def check(query)
    m = trycheck(query)
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus or iliedaboutcake something broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    saved_filter = getcached("chat_filter") || []
    if MODS.include?(@chatter.downcase) 
      if query =~ /^(!(enable_strims|disable_strims))/i
        self.purses = !(query =~ /^(!enable_strims)/i).nil?
        word = self.purses ? 'enabled' : 'disabled'
        # true if it's !enable, false otherwise
        return "!strims #{word} by #{@chatter}"
      end
    end
    isnewgame = false
    if game.nil? or game['done']
      isnewgame = true
      save(new_game(game))
    end
    # handle corner cases. notears
    game['purse'] ||= STARTCASH
    if query =~ /^!(hit|draw|bj)/ 
      bet if game['bet'] == 0
      if isnewgame
        return "/w #{@chatter} New Round: #{show} #{WHISPER_SUFFIX}"
      else
        return hit
      end
    elsif query =~ /^!sta/
      return stand
    elsif query =~ /^!bet/ or query =~ /^!double/
      parts = query.split(' ')
      if query =~ /^!double/
        return bet(game['bet'].to_i)
      else
        if(parts.length > 1)
          return bet(parts[1].to_i)
        else
          return "You must provide an amount to bet"
        end
      end
    elsif query =~ /^!purse/
      return "/w #{@chatter} Ð#{game['purse']} chips in your purse #{WHISPER_SUFFIX}"
    elsif query =~ /^!show/
      return "#{@chatter} is playing with #{show} Ð#{game['purse']} chips in purse"
    elsif query =~ /^!claim/
      # TODO let users get free chips every day
    end
    save
    return nil
  end
  def json_obj_to_game(gm)
    gm['deck'] = Deck.from_json(gm['deck']) if gm['deck'].is_a?(String)
    gm['player'] = Hand.from_json(gm['player'], gm['deck']) if gm['player'].is_a?(String)
    gm['dealer'] = Hand.from_json(gm['dealer'], gm['deck']) if gm['dealer'].is_a?(String)
    return gm
  end
  def game_to_jsn_string(gm)
    ['deck', 'player', 'dealer'].each do |k|
      gm[k] = gm[k].to_json unless gm[k].is_a?(String)
    end
    return gm
  end
  def save(thing=nil)
    self.game = thing.nil? ? game : thing
  end
  def game=(gm)
    setcached("game.#{@chatter.downcase}", game_to_jsn_string(gm))
  end
  def game
    gm = getcached("game.#{@chatter.downcase}")
    return gm.nil? ? nil : json_obj_to_game(gm)
  end
  def new_game(gm={})
    gm = {} if gm.nil?
    gm['deck'] = Deck.new
    gm['deck'].cards.shuffle!
    gm['player'] = Hand.new(gm['deck'])
    gm['dealer'] = Hand.new(gm['deck'])
    # testlog(gm)

    gm['bet'] = 0
    gm['done'] = false
    return gm
  end
  def bet(amount=0)
    if amount < 0
      return "/w #{@chatter} cannot bet negative values #{WHISPER_SUFFIX}"
    end
    amount = MINBLIND if amount < MINBLIND
    puts 'debugging bet game'
    puts game
    if amount > game['purse']
      return "/w #{@chatter} cannot afford to bet Ð#{amount} with a Ð#{game['purse']} purse (minimum is Ð#{MINBLIND}), try again tomorrow if you can afford the minimum. #{WHISPER_SUFFIX}"
    end
    game['bet'] += amount
    game['purse'] -= amount
    return "/w #{@chatter} bet Ð#{amount} chips on #{show} #{WHISPER_SUFFIX}"
  end

  def hit
    return "/w #{@chatter} Not enough bet to hit, need to bet at least Ð#{MINBLIND} #{WHISPER_SUFFIX}" if game['bet'] < MINBLIND
    game['player'].hit
    rv = ""
    if game['player'].bust?
      game['done'] = true
      rv << "#{@chatter} busted! #{show}. "
    else
      rv << "#{@chatter} You hit #{show}. #{WHISPER_SUFFIX}"
    end
    rv << "Ð#{game['purse']} left"
    return "/w #{rv}"
    # TODO: would the dealer draw right now?
  end
  
  def stand
    # dealer draws until he wins or flops
    h = game['player']
    d = game['dealer']
    # testlog(game)

    while d.value < 17 do
      d.hit      
    end
    if h.value > d.value or d.bust?
      # player wins
      op = "#{@chatter} wins Abathur"
      game['purse'] += (game['bet']*2)
    elsif h.value < d.value
      op = "#{@chatter} loses GameOfThrows"
    else
      op = "No one wins SoSad #{@chatter} gets a refund "
      game['purse'] += game['bet']
    end
    game['done'] = true
    return "/w #{op} #{show} Ð#{game['purse']} left"
  end

  def show(gm=nil)
    gm = game if gm.nil?
    h = gm['player']
    d = gm['dealer']
    # testlog(gm)

    rv = "#{h.value.to_s} "
    rv << "#{h.view.to_s}. "
    rv << "Dealer has: "
    rv << "#{d.value.to_s} "
    rv << " #{d.view.to_s}."
    return rv
  end

  def getjson(url)
    content = open(url).read
    return JSON.parse(content)
  end

  def purses
    return getcached('purses') || {}
  end

  def purses=(jsn)
    setcached('purses', jsn)
  end

  # safe cache! won't die if the bot dies
  def getcached(url)
    _cached = instance_variable_get "@cached_#{hashed(url)}"
    return _cached unless _cached.nil?
    path = CACHE_FILE + "#{hashed(url)}.json"
    if File.exists?(path)
      File.open(path, "r:UTF-8") do |f|
        _cached = JSON.parse(f.read)
        instance_variable_set("@cached_#{hashed(url)}", _cached)
        return _cached
      end 
    end
    return nil
  end
  def setcached(url, jsn)
    instance_variable_set("@cached_#{hashed(url)}", jsn)
    path = CACHE_FILE + "#{hashed(url)}.json"
    File.open(path, 'w') do |f2|
      f2.puts JSON.unparse(jsn)
    end
  end

  def hashed(url)
    return Digest::MD5.hexdigest(url).to_s
  end

  def testlog(g)
    puts "Dealer is... "
    puts g['dealer'].respond_to?(:value)
    puts "Player is... "
    puts g['player'].respond_to?(:value)
  end
end
