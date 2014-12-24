require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class RestartCounter
  MODS = %w{iliedaboutcake hephaestus 13hephaestus rustlebot bot destiny ceneza sztanpet}.map{|m| m.downcase}
  ENDPOINT = "restart_counter"
  VALID_WORDS = %w{restart counter}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
  end
  def check(query)
    m = trycheck(query)
    if @last_message.similar(m) >= 97
      # it's too similar. so it will get the bot banned
      m = "Destiny hasn\'t restarted any more yet. "
      m << ["SoDoge", "DaFeels", "NoTears", "SoSad"].sample
    end
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus something broke with !restart. Exception: #{m.to_s}"
  end
  def trycheck(query)
    output = "Destiny has restarted "
    cached = getcached(ENDPOINT)
    if cached.nil? or cached.has_key?("restarts") == false
      cached = {}
      cached["restarts"] = 0
      setcached(ENDPOINT, cached)
    end
    # if jester is setting the number
    parts = query.split(' ')
    if MODS.include?(@chatter) and parts.length > 1
      m_num = parts[1]
      puts "#{@chatter} is changing the count to: #{m_num}"
      unless m_num.nil? or m_num.length == 0
        # check if it's a number
        if m_num =~ /\A\d+\z/
          # set the new value
          cached["restarts"] = m_num.to_i
          setcached(ENDPOINT, cached)
        end
      end
    else
      puts "someone else is calling this: #{@chatter}"
    end
    restarts = cached["restarts"]
    output << "#{restarts} times. "
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