require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'cgi'
require 'digest'
require 'action_view'
include ActionView::Helpers::DateHelper

class NumberFacts
  FACTS_PER_REQUEST = 10
  # http://numbersapi.com/random/trivia
  # http://numbersapi.com/random/trivia?notfound=ceil

  ENDPOINT = "http://numbersapi.com/random/trivia"
  # TODO: get more at once, and cache them for faster facts
  VALID_WORDS = %w{number}
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_fact = 0
  end
  def check(query)
    return trycheck(query)
  rescue Exception => e
    puts e.message
    m = e.message
    m << "\n\n --->"
    m << e.backtrace.join("\n|\n")
    " SWEATSTINY tell hephaestus something broke with Number Facts. Exception: #{m.to_s}"
  end
  def trycheck(query)
    return open(ENDPOINT).read
    # temporarily for demo purposes

    cached = getcached(ENDPOINT) || {}
    cached["date"] ||= 0
    # expire cache if...
    if cached["date"].to_i < (Time.now.to_i - CACHE_DURATION)
      jsn = getjson(ENDPOINT)
      if jsn.nil?
        raise "Failed to GET Number Facts"
      else
        jsn["date"] ||= Time.now.to_i
        setcached(ENDPOINT, jsn)
      end
    else
      jsn = cached
    end

    fact = jsn['facts'][@last_fact]
    @last_fact = @last_fact + 1
    if @last_fact >= FACTS_PER_REQUEST
      @last_fact = 0
      jsn["date"] = 0
      setcached(ENDPOINT, jsn)
    end
    return fact
  end

  def getjson(url)
    content = open(url).read
    return JSON.parse(content)
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
