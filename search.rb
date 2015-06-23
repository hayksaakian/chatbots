require 'action_view'
require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
require 'searchbing'
include ActionView::Helpers::DateHelper

class Search
  include ActionView::Helpers::TextHelper
  VALID_WORDS = %w{search google bing}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"
  MAX_LENGTH = 256
  NUM_RESULTS = 10
  MOD_ONLY = true

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @bing = Bing.new(ENV['AZURE_API_ACCOUNT_KEY'], NUM_RESULTS, 'Web')
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @cache = {}
    @last_message = ""
    @last_question = ""
    @last_index = 0
  end
  def check(query, index=-1)
    query = extract_query(query)
    if @last_question.similar(query) > 98
      # it's too similar. so it will get the bot banned
      puts "Getting next Answer, Number #{index+1}"
      index = @last_index + 1
      if index > NUM_RESULTS-1
        msg = "Out of Answers. too much recursion"
      end
    else
      index = 0
    end
    msg = trycheck(query, index)
    @last_index = index
    @last_message = msg
    return msg
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " WhoahDude Tell hephaestus something broke with !moobies. Exception: #{m.to_s}"
  end
  def extract_query(query)
    parts = query.split(' ')
    parts.delete_at(0) if query[0] == "!"
    if parts.count > 0
      query = parts.join(' ')
    elsif !@last_question.nil? and (@last_question.length > 0)
      query = @last_question
    end
    return query
  end
  def trycheck(query, index=0)
    # TODO: don't return anything if destiny is live
    # cached = getcached(ENDPOINT)
    # sort by similarity to query, because rotten tomates doesn't sort
    if @cache[query].nil?
      @cache[query] = JSON.parse(@bing.search(query).to_json)
      @cache['searched_at'] = Time.now.to_i
    end
    if @cache[query].nil? or @cache[query][0]['Web'].count == 0
      return "No results #{@chatter}"
    end
    results = @cache[query]
    index = 0 if index.nil?
    if index >= results[0]['Web'].count
      puts results
      return "ERR: No more results found :("
    end
    @last_question = query
    result = results[0]['Web'][index]

    output = ""
    output << "#{index+1}) " unless index == 0
    output << "#{result['Title']}: "
    output << "DESC_HERE"
    output << " | source: #{result['Url']} via bing.com (may be nsfw)"

    output.gsub!("DESC_HERE", result["Description"].truncate(MAX_LENGTH-output.length))

    return output
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
