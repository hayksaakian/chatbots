require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
include ActionView::Helpers::DateHelper

DOGECOIN_ENDPOINT = "https://www.vaultofsatoshi.com/ticker_data.php?order_currency=DOGE&payment_currency=USD"
VALID_WORDS = %w{!doge !dogecoin !DOGE !DogeCoin !DGC}
RATE_LIMIT = 16 # seconds
CACHE_DURATION = 60 #seconds
APP_ROOT = File.expand_path(File.dirname(__FILE__))
CACHE_FILE = APP_ROOT+"/cache/"

class DogeFetcher
  attr_accessor :regex, :last_message
  def initialize
    @regex = /^!(doge|dgc| SoDoge|SoDoge)/i
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
    puts e.backtrace.join("\n")
    m = e.message
    " is SoSad . Bad SoDoge!! tell hephaestus something broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    output = "US$"
    cached = getcached(DOGECOIN_ENDPOINT)
    # expire cache if...
    if cached.nil? or cached["date"] < Time.now.to_i - CACHE_DURATION
      jsn = getjson(DOGECOIN_ENDPOINT)
      if jsn.nil?
        raise "Failed to GET price from Vault of Satoshi API"
      else
        setcached(DOGECOIN_ENDPOINT, jsn)
      end
    else
      jsn = cached
    end
    price = jsn["avg_price"].to_f
    # puts price
    suffix = " "
    if price < 1.0
      price = 1000.0*price
      suffix = " / 1000 DOGE "
    end
    output << price.to_s
    output << suffix
    if !cached.nil? and !jsn.nil? and jsn != cached
      delta = jsn["avg_price"].to_f - cached["avg_price"].to_f
      delta = delta.round(6)
      if delta != 0
        s = delta > 0 ? "SoDoge such increase. To the MOON!" : "SoSad bad SoDoge"
        output << "+" if delta > 0
        output << " "+delta.to_s
        output << " "+s
      end
    end
    output << " as of "
    output << time_ago_in_words(Time.at(jsn["date"]))
    output << " ago"
    # output << " i finished checking at "+time_ago_in_words(Time.now)
    return output
  end

  def getjson(url)
    content = open(url).read
    return JSON.parse(content)
  end

  # safe cache! won't die if the bot dies
  def getcached(url)
    return @cached_json if !@cached_json.nil?
    path = CACHE_FILE + hashed(url) + ".json"
    if File.exists?(path)
      f = File.open(path)
      return JSON.parse(f.read)
    end
    return nil
  end
  def setcached(url, jsn)
    @cached_json = jsn
    path = CACHE_FILE + hashed(url) + ".json"
    File.open(path, 'w') do |f2|
      f2.puts JSON.unparse(jsn)
    end
  end

  def hashed(url)
    return Digest::MD5.hexdigest(url).to_s
  end
end