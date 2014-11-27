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

  attr_accessor :regex, :last_message
  def initialize
    Rotten.api_key = ENV['ROTTEN_TOMATOES_API_KEY']
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @cache = {}
    @last_message = ""
    @last_moobie = ""
  end
  def set_chatter(name)
    @chatter = name
  end
  def check(query, index=0)
    index = 0 if index.nil?
    msg = trycheck(query, index)
    if @last_message.similar(msg) == 100
      # it's too similar. so it will get the bot banned
      puts "Getting next Moobie"
      if index > 29
        msg = "Out of moobies. too much recursion"
      else
        msg = check(query, index+1)
      end
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
    if parts.count > 0
      query = parts.join(' ')
    else
      query = @last_moobie
    end
    # sort by similarity to query, because rotten tomates doesn't sort
    if @cache[query].nil?
      @cache[query] = RottenMovie.find(:title => query)
      # the API can return nil, a single moobie, or an array
      # so let's coerce to an array
      if @cache[query].is_a?(Array) == false and !@cache[query].nil?
        @cache[query] = [@cache[query]]
      end
      if @cache[query].count > 1 and !@cache[query].nil?
        @cache[query].sort_by!{|m| m.title.similar(query)}
        @cache[query].reverse! unless @cache[query].nil?
      end
    end
    if @cache[query].nil? or @cache[query].count == 0
      return "No results #{@chatter}"
    end
    movies = @cache[query]
    index = 0 if index.nil?
    if index >= movies.count
      puts movies
      return "ERR: No more moobies found :("
    end
    @last_moobie = query
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
    output = ""
    output << "#{index+1}) " unless index == 0
    output << "#{movie.title} "
    output << "(#{movie.year}) " if (!movie.year.nil? and (movie.year.to_s.length > 0))
    output << "#{movie.runtime} min. " if (!movie.runtime.nil? and (movie.runtime.to_s.length > 0))
    if movie.ratings.critics_score > -1
      output << " - critics rated: #{movie.ratings.critics_score}/100 "
      output << " - audience rated: #{movie.ratings.audience_score}/100 " unless movie.ratings.audience_score <= 0
    end
    output << "- via #{movie.links.alternate}"
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
