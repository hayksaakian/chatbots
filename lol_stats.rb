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
  # ENDPOINT = "http://na.op.gg/summoner/userName=NeoD%C3%A9stiny"
  ENDPOINT = "https://na.api.pvp.net/api/lol/na/v1.3/game/by-summoner/26077457/recent?api_key=#{ENV['LOL_API_KEY']}"
  CHAMPION_ENDPOINT = "https://na.api.pvp.net/api/lol/static-data/na/v1.2/champion?api_key=#{ENV['LOL_API_KEY']}"
  STATS_ENDPOINT = "https://na.api.pvp.net/api/lol/na/v1.3/stats/by-summoner/26077457/summary?api_key=#{ENV['LOL_API_KEY']}"
  LEAGUE_ENDPOINT = "https://na.api.pvp.net/api/lol/na/v2.5/league/by-summoner/26077457/entry?api_key=#{ENV['LOL_API_KEY']}"
  USER_ENDPOINT = "http://matchhistory.na.leagueoflegends.com/en/#match-history/NA/40774766"

  UA = "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.115 Safari/537.36"
  VALID_WORDS = %w{lol league heimerdonger dravewin surprise}
  RATE_LIMIT = 16 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    cl = getjson(CHAMPION_ENDPOINT)
    @champion_names = {}
    cl['data'].each do |code_name, details|
      @champion_names[details['id']] = details['name']
    end
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
      # TODO: consider checking 
      # https://na.api.pvp.net/observer-mode/rest/consumer/getSpectatorGameInfo/NA1/26077457
      # to see if a game is live
      # and show different stats

      page = getjson(ENDPOINT)
      recent_game = page["games"][0]
      recent_stats = recent_game['stats']
      cached["kda"] = "(#{recent_stats['championsKilled']} / #{recent_stats['numDeaths']} / #{recent_stats['assists']})"
      cached["champion_name"] = @champion_names[recent_game['championId']]
      cached["mode"] = recent_game['subType']
      cached["last_win_or_loss"] = recent_stats['win']

      rank_stats = getjson(LEAGUE_ENDPOINT).values[0][0]
      cached["rank"] = "#{rank_stats['tier']} #{rank_stats['entries'][0]['division']}"
      cached["rank"] += " #{rank_stats['entries'][0]['leaguePoints']}/100 LP"
      cached["win_loss_ratio"] = "#{rank_stats['entries'][0]['wins']} / #{rank_stats['entries'][0]['losses']}"
      cached["when"] = Time.at(recent_game["createDate"].to_f / 1000.000)

      cached["date"] ||= Time.now.to_i

      # page = Nokogiri::HTML(open(ENDPOINT, 'User-Agent' => UA, 'Accept-Language' => 'en-GB,en-US;q=0.8,en;q=0.6'))
      # cached["kda"] = page.css(".GameStats .kda")[0].text.strip.gsub("\n", " ").gsub("\t", "").strip
      # cached["champion_name"] = page.css(".GameSimpleStats .championName")[0].text.strip
      # cached["win_loss_ratio"] = page.css(".SummonerRankWonLine").text.gsub("All ranked games", "").strip
      # cached["mode"] = page.css(".GameBox .GameType .subType")[0].text.split('-').first.gsub("\t", "").gsub("\n", "").strip
      # cached["last_win_or_loss"] = page.css(".GameBox .gameResult")[0].text.strip
      # cached["rank"] = page.css(".tierRank").text.strip
      # ntzt = page.css(".GameBox ._timeago")[0].text.strip
      # cached["when"] = Time.parse("#{ntzt} +0700")
      setcached(ENDPOINT, cached)
    end
    game = cached
    # might not have good json
    result = game["last_win_or_loss"] ? "won" : "lost"
    summoner = "Destiny"
    character = game['champion_name']

    # Destiny lost a solo game on King Sejong Station LE 7h9m ago. sc2ranks.com/character/us/310150/Destiny
    out_parts = []
    out_parts << " #{summoner} #{result} a game "
    out_parts << " (#{game["kda"]}) as #{character} "
    out_parts << " ranked #{game["rank"]} "
    out_parts << " in #{game['mode']} started #{time_ago_in_words(game['when'])} ago. " 
    out_parts << " #{USER_ENDPOINT} "
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
