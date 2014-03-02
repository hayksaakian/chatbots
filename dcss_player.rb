require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'

# RATE_LIMIT = 16 # seconds
# CACHE_DURATION = 60 #seconds
APP_ROOT = File.expand_path(File.dirname(__FILE__))
CACHE_FILE = APP_ROOT+"/cache/"
LONGER_COMMANDS = %w{up down left right enter escape}

class DcssPlayer
  attr_accessor :regex

  def get_regex
    re = LONGER_COMMANDS.join("|")
    # TODO only take first character for plain commands
    re = /^(#{re}|[A-Z])/i
    return re
  end

  def initialize
    @regex = get_regex
  end

  def ready
    return true
  end
  def check(query)
    # query = query.downcase # breaks some commands
    query = query.strip
    rawquery = query
    query = query.match(@regex).to_s
    return nil if query == "" or query == nil
    return trycheck("escape") if @last_move == "*" and query == "q"
    return trycheck("N") if @last_move == "S"
    if query == "esc"
      query = "escape"
    end
    push_to_cache('commands', query)
    puts "doing "+query
    @last_move = query
    tms = 1
    if LONGER_COMMANDS.include?(query) and rawquery.length > query.length
      num = rawquery[query.length..query.length]
      puts "got num: #{num}"
      if num.to_i > 0
        tms = num.to_i
        puts "#{num} times"
      end
    end
    (tms-1).times do
      trycheck(query)
      sleep 0.50
    end
    return trycheck(query)
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " is SoSad . Bad SoDoge!! tell hephaestus something broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    `tmux send-keys -t game:0 #{query}`
    return ""
  end

  def push_to_cache(key, value)
    c = getcached(key) || []
    c.push value
    setcached(key, c)
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