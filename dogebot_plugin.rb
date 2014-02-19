#!/usr/bin/ruby
require 'net/http'
require 'cinch'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'

DOGECOIN_ENDPOINT = "https://www.vaultofsatoshi.com/ticker_data.php?order_currency=DOGE&payment_currency=USD"
VALID_WORDS = %w{!doge !dogecoin !DOGE !DogeCoin !DGC}
RATE_LIMIT = 2 # seconds
CACHE_DURATION = 30 #seconds
APP_ROOT = File.expand_path(File.dirname(__FILE__))
CACHE_FILE = APP_ROOT+"/cache/"
# example
# {
#   "hour": "2014-02-18 03:00:00",
#   "min_price": "0.00141414",
#   "max_price": "0.00155740",
#   "avg_price": "0.00149",
#   "units_traded": "16477479.51465777",
#   "number_of_trades": "202",
#   "opening_price": "0.00152000",
#   "closing_price": "0.00151000",
#   "date": 1392780497,
#   "volume_1day": "16477479.51465777",
#   "volume_7day": "106482351.25908490",
#   "CacheHit": 1
# }

class DogebotPlugin
  include Cinch::Plugin
  match /(doge|dgc)/i

  def check(query)
    output = "US$"
    cached = getcached(DOGECOIN_ENDPOINT)
    # expire cache if...
    if cached.nil? or (cached["date"] > (Time.now.to_i - CACHE_DURATION))
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
    puts price
    suffix = " "
    if price < 1.0
      price = 1000.0*price
      suffix = " / 1000 DOGE "
    end
    output << price.to_s
    output << suffix
    if !cached.nil? and !jsn.nil? and jsn != cached
      delta = jsn["avg_price"] - cached["avg_price"]
      if delta != 0
        s = delta > 0 ? "SoDoge such increase. To the MOON!" : "SoSad bad SoDoge"
        output << "+" if delta > 0
        output << " "+delta.to_s
        output << " "+s
      end
    end
    output << " as of "
    output << Time.at(jsn["date"]).to_s
    return output
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " is SoSad . Bad SoDoge!! tell hephaestus something broke. Exception: #{m.to_s}"
  end

  def execute(m, query)
    puts 'got message!'
    last_time = @last_time || 0
    now = Time.now.to_i
    if now - last_time > RATE_LIMIT
      @last_time = now
      m.reply check(query)
    end
  end


  private
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