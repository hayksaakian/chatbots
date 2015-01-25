require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class Raffle
  ENDPOINT = "destiny.gg/subscribe"
  VALID_WORDS = %w{raffle}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"
  COOLDOWN = 20
  MINIMUM = 5
  DRAWING_FREQUENCY # 15 minutes
  PRIZE = "MEME"

  attr_accessor :regex, :last_message, :chatter, :msg_meta
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
    @last_time = Time.at(0)
    @last_drawing = Time.at(0)
    @msg_meta = {}
    @last_one = 0
  end
  def check(query)
    return trycheck(query)
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus something broke with !raffle. Exception: #{m.to_s}"
  end
  def pickone
    phrases = [
      "#{ENDPOINT} subscribe to qualify for the !raffle !!! $#{MINIMUM.to_s} to qualify for the #{PRIZE} drawing!",
      "Subscribe for the #{MEME} raffle! #{ENDPOINT} Minimum TIER 1 (#{MINIMUM.to_s} dollar) sub to qualify!",
      "Min. $#{MINIMUM.to_s} subscription to qualify for the raffle! 1) GO HERE #{ENDPOINT} 2) type !raffle",
      "Enter the raffle with at least a T1 - $#{MINIMUM.to_s} subscription and say !raffle in chat. #{ENDPOINT} Type !raffle to add your name to the list! Winner gets a used MEME"
    ]
    @last_one = 0 if @last_one >= phrases.length
    phrase = phrases[@last_one]
    @last_one = @last_one + 1
    return phrase
  end
  def trycheck(query)
    puts Time.now - @last_time
    output = ""
    if (Time.now - @last_time) > COOLDOWN
      @last_time = Time.now
      output << pickone
    else
      puts 'bad check'
    end    
    if query =~ /^!raffle/
      if @msg_meta["features"].include?("subscriber")
        
      else
        return pickone
      end
    end
    return output
  end

  # safe cache! won't die if the bot dies
  def getcached(url)
    _cached = instance_variable_get "@cached_#{hashed(url)}"
    return _cached unless _cached.nil?
    path = CACHE_FILE + "#{hashed(url)}.json"
    if File.exists?(path)
      f = File.open(path)
      _cached = JSON.parse(f.read)
      instance_variable_set("@cached_#{hashed(url)}", _cached)
      return _cached
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
