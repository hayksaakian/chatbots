require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'cgi'
require 'digest'
require 'action_view'
include ActionView::Helpers::DateHelper

class CsgoStats
  ENDPOINT = "http://csgo-stats.com/llllIIIllIIIlIIIIlllIIII/?ajax&uptodate"
  HUMAN_LINK = "http://csgo-stats.com/llllIIIllIIIlIIIIlllIIII/"
  VALID_WORDS = %w{cs csgo counterstrike ayyylmao}
  RATE_LIMIT = 16 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
  end
  def ready
    last_time = @last_time || 0
    now = Time.now.to_i
    if now - last_time > RATE_LIMIT
      @last_time = now
      return true
    end
    return false
  end
  def check(query)
    return trycheck(query)
  rescue Exception => e
    puts e.message
    m = e.message
    m << "\n\n --->"
    m << e.backtrace.join("\n|\n")
    " AYYYLMAO tell hephaestus something broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    cached = getcached(ENDPOINT) || {}
    cached["date"] ||= 0
    # expire cache if...
    if cached["date"].to_i < (Time.now.to_i - CACHE_DURATION)
      jsn = getjson(ENDPOINT)
      if jsn.nil?
        raise "Failed to GET CSGO data from csgo-stats.com"
      else
        jsn["date"] ||= Time.now.to_i
        setcached(ENDPOINT, jsn)
      end
    else
      jsn = cached
    end

    parsed_html = Nokogiri.parse(jsn["content"])
    lastmatch = parsed_html.css("#lastmatch")
    lmtxt = lastmatch.children[3].text()
    result = lmtxt.include?('Win') ? 'won' : 'lost'
    if lmtxt.include?('.')
      lmtxt = lmtxt.split('.')[0]
    end
    # contains lifetime stats
    misc_data = parsed_html.css('#misc').children[3].children[3]
    # matches won / played
    overall = "#{misc_data.children[15].text.chomp} / #{misc_data.children[11].text.chomp}"
    return "Destiny #{result} a game with #{lmtxt} (#{overall} games won overall) #{HUMAN_LINK}"
    # output << " as of "
    # output << time_ago_in_words(Time.at(jsn["date"]))
    # output << " ago"
    # # output << " i finished checking at "+time_ago_in_words(Time.now)
    # return output
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