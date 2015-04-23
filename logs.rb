require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'cgi'
require 'digest'
require 'action_view'
include ActionView::Helpers::DateHelper

class Logs
  ENDPOINT = "http://overrustlelogs.net/destinygg"
  HUMAN_ENDPOINT = "http://overrustlelogs.net/Destinygg%20chatlog"
  VALID_WORDS = %w{log chatlog}
  RATE_LIMIT = 16 # seconds
  NAME_UPDATE_FREQUENCY = 60
  # CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message, :last_name_update, :names
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @names = getjson(ENDPOINT)
    @last_name_update = Time.now.to_i
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
    m = e.message
    m << "\n\n --->"
    m << e.backtrace.join("\n|\n")

    puts m
    " Heimerdonger tell hephaestus something broke with logs. Exception: #{e.message.to_s}"
  end
  def trycheck(query)
    name = query.split(' ')[1]
    if Time.now.to_i - @last_name_update > NAME_UPDATE_FREQUENCY
      @last_name_update = Time.now.to_i
      @names = getjson(ENDPOINT)        
    end
    if name.nil?
      return "#{HUMAN_ENDPOINT}/#{Time.now.strftime('%B %Y').gsub(' ', '%20')}"
    elsif @names.has_key?(name.downcase)
      return @names[name.downcase]['url']
    else
      return "No logs for #{name}"
    end
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