require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
include ActionView::Helpers::DateHelper

VALID_WORDS = %w{!spin !roll !submit}
RATE_LIMIT = 3 # seconds
APP_ROOT = File.expand_path(File.dirname(__FILE__))
CACHE_FILE = APP_ROOT+"/cache/"

class Roulette
  attr_accessor :regex, :last_message
  def initialize
    @regex = /^!(spin|roll|submit)/i
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
    return process(query)
  rescue Exception => e
    m = e.message
    puts m
    puts e.backtrace.join("\n")
    return " is SoSad . Tell hephaestus something broke. Exception: #{m.to_s}"
  end
  def process(query)
    output = ""
    if query.index("!submit ") == 0
      lnka = query.split(' ')
      lnka.shift # get rid of the !submit
      lnk = lnka.shift
      output << submit(lnk)
    else
      result = spin
      output << '[#'
      output << result[:num].to_s
      output << '] '
      output << result[:url]
      output << ' (assume NSFW )'
    end
    return output
  end

  def submit(url)
    if url.index("http") != -1
      key = "urls"
      urls = getcached(key) || []
      urls.push url
      setcached(key, urls)
      return 'thanks for submitting #'+urls.length.to_s
    else
      return 'just urls pls'
    end
  end

  def spin
    urls = getcached("urls") || []
    url = urls.sample
    num = 1 + urls.index(url)
    return {url:url, num:num}
  end

  def getjson(loc)
    content = open(loc).read
    return JSON.parse(content)
  end

  # safe cache! won't die if the bot dies
  def getcached(key)
    return @cached_json if !@cached_json.nil?
    path = CACHE_FILE + hashed(key) + ".json"
    if File.exists?(path)
      f = File.open(path)
      return JSON.parse(f.read)
    end
    return nil
  end
  def setcached(key, obj)
    @cached_json = obj
    path = CACHE_FILE + hashed(key) + ".json"
    File.open(path, 'w') do |f2|
      f2.puts obj.to_json
    end
  end

  def hashed(key)
    return Digest::MD5.hexdigest(key).to_s
  end
end