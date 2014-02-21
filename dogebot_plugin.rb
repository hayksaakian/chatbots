#!/usr/bin/ruby
require 'net/http'
require 'cinch'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'

require_relative 'doge_fetcher'

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
fetcher = DogeFetcher.new

class DogebotPlugin
  include Cinch::Plugin
  match /(doge|dgc)/i

  def check(query)
    fetcher.check(query)
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

end