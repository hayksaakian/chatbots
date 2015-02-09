require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class Broadcaster
  ENDPOINT = "https://www.twitchalerts.com/donate/destiny"
  VALID_WORDS = %w{roof donat sell}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"
  COOLDOWN = 20
  MINIMUM = 5

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /(roof|donat|^!(#{VALID_WORDS.join('|')}))/i
    @last_message = ""
    @last_time = Time.at(0)
    @last_one = 0
  end
  def check(query)
    return trycheck(query)
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus something broke. Exception: #{m.to_s}"
  end
  def pickone
    phrases = [
      "#{ENDPOINT} WORTH $#{MINIMUM.to_s} to get your Message read by Robot Lady",
      "Click for DANKMEMES : #{ENDPOINT}  Robot Lady will read messages on donations over than #{MINIMUM.to_s} dollars",
      "Min. $#{MINIMUM.to_s} donation for Robot Lady to read it! Donation Link: #{ENDPOINT}",
      "Robot Lady will read your DANKMEMES for at least $#{MINIMUM.to_s} donations. Donate Here: #{ENDPOINT}"
    ]
    @last_one = 0 if @last_one >= phrases.length
    phrase = phrases[@last_one]
    @last_one = @last_one + 1
    return phrase
  end
  def trycheck(query)
    puts Time.now - @last_time
    if (Time.now - @last_time) > COOLDOWN
      @last_time = Time.now
      output = pickone
      return output
    else
      puts 'bad check'
      return nil
    end
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
