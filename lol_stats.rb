require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'nokogiri'
require 'cgi'
require 'digest'
require 'action_view'
include ActionView::Helpers::DateHelper

class LolStats
  ENDPOINT = "http://na.op.gg/summoner/userName=NeoD%C3%A9stiny"
  UA = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.115 Safari/537.36"
  VALID_WORDS = %w{lol league heimerdonger dravewin surprise}
  RATE_LIMIT = 16 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message
  def initialize
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
    " Heimerdonger tell hephaestus something broke with !lol. Exception: #{e.message.to_s}"
  end
  def trycheck(query)
    cached = getcached(ENDPOINT) || {}
    cached["date"] ||= 0
    # expire cache if...
    if cached["date"].to_i < (Time.now.to_i - CACHE_DURATION)
      page = Nokogiri::HTML(open(ENDPOINT, 'User-Agent' => UA, 'Accept-Language' => 'en-GB,en-US;q=0.8,en;q=0.6'))
      cached["kda"] = page.css(".GameStats .kda")[0].text.strip.gsub("\n", " ").gsub("\t", "").strip
      cached["champion_name"] = page.css(".GameSimpleStats .championName")[0].text.strip
      cached["win_loss_ratio"] = page.css(".SummonerRankWonLine").text.gsub("All ranked games", "").strip
      cached["mode"] = page.css(".GameBox .GameType .subType")[0].text.split('-').first.gsub("\t", "").gsub("\n", "").strip
      cached["last_win_or_loss"] = page.css(".GameBox .gameResult")[0].text.strip
      cached["rank"] = page.css(".tierRank").text.strip
      ntzt = page.css(".GameBox ._timeago")[0].text.strip
      cached["when"] = Time.parse("#{ntzt} +0600")
      cached["date"] ||= Time.now.to_i
      setcached(ENDPOINT, cached)
    end
    game = cached
    # might not have good json
    result = game["last_win_or_loss"] == "Victory" ? "won" : "lost"
    summoner = "Destiny"
    character = game['champion_name']

    # Destiny lost a solo game on King Sejong Station LE 7h9m ago. sc2ranks.com/character/us/310150/Destiny
    out_parts = []
    out_parts << " #{summoner} #{result} a game "
    out_parts << " (#{game["kda"]}) as #{character} "
    out_parts << " ranked #{game["rank"]} "
    out_parts << " in #{game['mode']} #{time_ago_in_words(game['when'])} ago. " 
    out_parts << " #{ENDPOINT} "
    output = out_parts.join(' ')
    if output.similar(@last_message) >= 70
      out_parts.shuffle!
      output = out_parts.join(' ')
    end
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