require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
require 'youtube_search'
include ActionView::Helpers::DateHelper

class Youtube
  VALID_WORDS = %w{youtube.com youtu.be}
  REGEX = /(youtu\.be\/.+|(www\.)?youtube\.com\/.+[?&]v=.+)/
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message
  def initialize
    @regex = REGEX
    @cache = {}
    @last_message = ""
  end
  def set_chatter(name)
    @chatter = name
  end
  def check(query)
    msg = trycheck(query)
    # don't bother saying anything if we already linked it
    return nil if @last_message.similar(msg) > 95
    @last_message = msg
    return msg
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " UWOTM8 Tell hephaestus the Youtube script broke because of Exception: #{m.to_s}"
  end
  def trycheck(query)
    parts = query.split(' ')
    # assumes there is a part that matches the regex
    found_link = parts.select{|pt| pt =~ REGEX ? true : false }.first

    uri = URI.parse(found_link)
    v_id = uri.query.split('&').select {|a| a.start_with? 'v='}[0]

    @cache[v_id] ||= YoutubeSearch.search(v_id, 'max-results' => 1).first

    video = @cache[v_id]
    return nil if video.nil?
    output = video['title']
    video['duration'] = video['duration'].to_f

    hours = (video['duration']/3600.to_f).floor
    if hours > 0
      output << " #{hours.to_i}h"
      video['duration'] -= (hours.to_f*3600.to_f)
    end
    
    minutes = (video['duration'].to_f / 60.to_f).floor
    if minutes > 0
      output << " #{minutes.to_i}m"
      video['duration'] -= (minutes.to_f*60.to_f)
    end
    
    # seconds
    if video['duration'] > 0
      output << " #{video['duration'].to_i}s"
    end

    # published at
    published_at = Time.parse(video['published']).strftime("%b %d, %Y")
    output << " published on #{published_at}"
    
    return "#{@chatter} linked #{output}"
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
