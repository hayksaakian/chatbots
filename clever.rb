require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
require 'cleverbot'
include ActionView::Helpers::DateHelper

class Clever
  ENDPOINT = "http://overrustle.com:6081/api"
  VALID_WORDS = %w{rustlebot clever}
  MODS = %w{iliedaboutcake hephaestus 13hephaestus bot destiny ceneza sztanpet}.map{|m| m.downcase}
  FILTERED_STRIMS = %w{clickerheroes s=advanced strawpoii}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex
  def initialize
    @bot = Cleverbot::Client.new # note casing!
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
  end
  def set_chatter(name)
    @chatter = name
  end
  def check(query)
    m = trycheck(query)
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " NoTears Tell hephaestus something broke with !rustlebot. Exception: #{m.to_s}"
  end
  def trycheck(query)
    # TODO filter input
    saved_filter = getcached("chat_filter") || []

    parts = query.split(' ')
    parts.delete_at(0)
    query = parts.join(' ')

    return @bot.write query
  end

  # safe cache! won't die if the bot dies
  def getcached(url)
    return @cached_json if !@cached_json.nil?
    path = CACHE_FILE + url + ".json"
    if File.exists?(path)
      f = File.open(path)
      return JSON.parse(f.read)
    end
    return nil
  end
  def setcached(url, jsn)
    @cached_json = jsn
    path = CACHE_FILE + url + ".json"
    File.open(path, 'w') do |f2|
      f2.puts JSON.unparse(jsn)
    end
  end

  def hashed(url)
    return Digest::MD5.hexdigest(url).to_s
  end
end
