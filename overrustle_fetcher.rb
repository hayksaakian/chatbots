require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class OverrustleFetcher
  ENDPOINT = "http://overrustle.com:9998/api"
  VALID_WORDS = %w{strim strims overrustle OverRustle}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
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
    m = trycheck(query)
    if @last_message.similar(m) >= 97
      # it's too similar. so it will get the bot banned
      m = "Top 3 strims are the same as before, but view counts might have changed. "
      m << ["AYYYLMAO", "Hhhehhehe", "DuckerZ", "NoTears"].sample
      m << " strim list found on overrustle.com/strims  RustleBot by hephaestus"
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
    # TODO: don't return anything if destiny is live
    output = "Top 3 OverRustle.com strims: "
    # cached = getcached(ENDPOINT)
    # expire cache if...
    jsn = getjson(ENDPOINT)
    # if cached.nil? or cached["date"] < Time.now.to_i - CACHE_DURATION
    #   jsn = getjson(ENDPOINT)
    #   if jsn.nil?
    #     raise "Bad JSON from API"
    #   else
    #     setcached(ENDPOINT, jsn)
    #   end
    # else
    #   jsn = cached
    # end
    strims = jsn["streams"]
    list_of_lists = strims.sort_by{|k,v| -v}.take(3)
    list_of_lists.each do |sl|
      output << "\n#{sl[1]} - overrustle.com#{sl[0]}"
    end
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