require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
require 'rottentomatoes'
include ActionView::Helpers::DateHelper

class Moobie
  include RottenTomatoes
  VALID_WORDS = %w{movie moobie moovie}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex
  def initialize
    Rotten.api_key = ENV['ROTTEN_TOMATOES_API_KEY']
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @cache = {}
    @last_message = ""
  end
  def check(query, index=0)
    msg = trycheck(query, index)
    if @last_message.similar(msg) >= 90
      # it's too similar. so it will get the bot banned
      msg = check(query, index+1)
    end
    @last_message = msg
    return msg
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " WhoahDude Tell hephaestus something broke with !moobies. Exception: #{m.to_s}"
  end
  def trycheck(query, index=0)
    # TODO: don't return anything if destiny is live
    # cached = getcached(ENDPOINT)
    parts = query.split(' ')
    parts.delete_at(0)
    query = parts.join(' ')
    @cache[query] ||= RottenMovie.find(:title => query)
    movies = @cache[query]
    if index >= movies.count
      puts @cache[query]
      return "No more moobies found :("
    end
    movie = movies[index]
    # because their search is bad, we'll try
    # and match the moobies year to what's specified in the 
    # original search query
    if index == 0
      movies.each do |m|
        if query.include?(m.year.to_s)
          movie = m
          break
        end
      end
    end
    prefix = index==0 ? "" : "#{index+1}) "
    output = "#{prefix}#{movie.title} (#{movie.year}) - critics rated: #{movie.ratings.critics_score}/100 audience rated: #{movie.ratings.audience_score}/100 - via #{movie.links.alternate}"
    puts output
    # expire cache if...
    # jsn = getjson(ENDPOINT)
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
    return output
  end

  def getjson(url)
    content = open(url).read
    return JSON.parse(content)
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
