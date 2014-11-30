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
  def getcached(url)
    _cached = instance_variable_get "@cached_#{hashed(url)}"
    return _cached unless _cached.nil?
    path = CACHE_FILE + "#{url}.json"
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
    path = CACHE_FILE + "#{url}.json"
    File.open(path, 'w') do |f2|
      f2.puts JSON.unparse(jsn)
    end
  end

  def hashed(key)
    return Digest::MD5.hexdigest(key).to_s
  end
end