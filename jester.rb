require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class Jester
  ENDPOINT = "jester"
  VALID_WORDS = %w{jester}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
  end
  def set_chatter(name)
    @chatter_name = name
  end
  def check(query)
    m = trycheck(query)
    if @last_message.similar(m) >= 97
      # it's too similar. so it will get the bot banned
      m = "Jester hasn\'t saved any more lives yet. "
      m << ["SoDoge", "DaFeels", "NoTears", "SoSad"].sample
    end
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus something broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    output = "jester? he\'s a pretty cool guy. "
    cached = getcached(ENDPOINT)
    if cached.nil? or cached.has_key?("lives") == false
      cached = {}
      cached["lives"] = 0
      setcached(ENDPOINT, cached)
    end
    # if jester is setting the number
    parts = query.split(' ')
    if @chatter_name == ENDPOINT and parts.length > 1
      m_num = parts[1]
      puts "jester is changing the count to: #{m_num}"
      unless m_num.nil? or m_num.length == 0
        # check if it's a number
        if m_num =~ /\A\d+\z/
          # set the new value
          cached["lives"] = m_num.to_i
          setcached(ENDPOINT, cached)
        end
      end
    else
      puts "someone else is calling this: #{@chatter_name}"
    end
    lives = cached["lives"]
    output << "jester saved #{lives} lives. Klappa"
    return output
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