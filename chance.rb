require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
require 'blackjack1'
include ActionView::Helpers::DateHelper

class Chance
  ENDPOINT = "http://us.battle.net/api/sc2/profile/310150/1/Destiny/matches"
  VALID_WORDS = %w{bet purse}
  MODS = %w{iliedaboutcake hephaestus 13hephaestus bot destiny ceneza sztanpet}.map{|m| m.downcase}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"
  STARTCASH = 100
  MINBLIND = 5

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @games = {}
    @deck = CardDeck::Deck.new
    Hand.deck = @deck
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
    if query =~ /^!hit/
      hit
    end
    return nil
  end
  def game
    return @games[@chatter]
  end
  def draw
    if game['bet'] < MINBLIND
      if game['purse'] >= MINBLIND
        game['purse'] -= MINBLIND
        game['bet'] += MINBLIND
      else
        return "#{@chatter} can't afford the minimum bet with a Ð#{game['purse']} purse, try again tomorrow."
      end
    end
    game['deck'] = CardDeck::Deck.new
    Hand.deck = 
    game['player'] = Hand.new
    game['dealer'] = Hand.new
  end
  def hit
    h = game['player']
    h.hit
    if h.bust?
      return "#{@chatter} busted! #{show}"
    else
      return "#{@chatter} hit. #{show}"
    end
  end
  
  def stand
    # dealer draws until he wins or flops
    h = game['player']
    d = game['dealer']
    while d.value < 17 do
      d.hit      
    end
    if h.value > d.value
      # player wins
      op = "#{@chatter} wins Abathur"
    elsif h.value < d.value
      op = "#{@chatter} loses GameOfThrows"
    else
      op = "No one wins SoSad"
    end
    return "#{op} #{show}"
  end

  def show(gm=nil)
    gm = game if gm.nil?
    h = gm['player']
    dh = gm['dealer']
    return "#{h.value.to_s} #{h.view.to_s}. Dealer has: #{dh.value.to_s} #{dh.view.to_s}."
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
end
