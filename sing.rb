require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'cgi'
require 'digest'
require 'action_view'
include ActionView::Helpers::DateHelper

# TODO
# find some way to periodically spit out messages
# instead of responding directly to them
class Sing
  SEARCH_ENDPOINT = "http://search.azlyrics.com/search.php?q="
  # kanye+better+faster+stronger
  VALID_WORDS = %w{sing stop_singing}
  RATE_LIMIT = 16 # seconds
  CACHE_DURATION = 60*60*24*7 #7 days in seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message, :current_song, :current_line

  def initialize
    current_line = 0
    @regex = /^!(#{VALID_WORDS.join('|')})/i
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
    " tell hephaestus something broke with #{self.class.name}. Exception: #{e.message.to_s}"
  end
  def trycheck(query)
    parts = query.split(' ')
    command = parts[0]


    return unless command =~ /^!sing/i
    parts.delete_at(0)

    sname = URI.escape(parts.join(" ")).gsub('%20', '+')

    cached = getcached(sname) || {}
    cached["date"] ||= 0
    # expire cache if...
    if cached["date"].to_i < (Time.now.to_i - CACHE_DURATION)
      search_results = Nokogiri::HTML(open("#{SEARCH_ENDPOINT}#{sname}"))
      anything = search_results.css('.hrlinks') ? true : false
      return "No lyrics for that search" unless search_results.css('.hrlinks')
      lyrics_url = sr.css('.sen a').first.attributes['href'].value
      lyrics_page = Nokogiri::HTML(open(lyrics_url))

      lyrics_started = false
      lyrics = ""
      counter = 0
      lyrics_page_text_lines = lyrics_page.text.lines
      lyrics_page.to_s.each_line do |ln|
        # intentional
        counter += 1
        if lyrics_started
          lyrics_started = !ln.include?("end of lyrics")
          break unless lyrics_started
          lyric = lyrics_page_text_lines[counter].chomp
          lyrics << lyric unless lyric.chomp.empty?
        elsif ln.include?("start of lyrics")
          lyrics_started = true 
        end
      end
      cached["lyrics"] = lyrics
      if lyrics.empty?
        raise "Failed to GET LoL data from lolking"
      else
        cached["title"] = lyrics_page.title
        cached["date"] ||= Time.now.to_i
        setcached(sname, cached)
      end
    end
    lyrics_lines = cached["lyrics"].lines
    if @current_line < lyrics_lines.length
      output = lyrics_lines[@current_line]
      @current_line += 1
      return output
    end
    return "/me I sang ~~ #{cached['title']}"
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