require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
require 'mechanize'
include ActionView::Helpers::DateHelper

class Rank
  ENDPOINT = "http://overrustlelogs.net/Destinygg%20chatlog" # / #{month}
  def get_endpoint
    return "#{ENDPOINT}/#{@now.strftime('%B')}%20#{@now.strftime('%Y')}/userlogs/?C=S;O=D"
  end
  RANK_PERCENTS = [0.55, 1.36, 10.88, 15.03, 34.83, 27.28, 10.08]
  PERCENTILES = RANK_PERCENTS.map{|x| RANK_PERCENTS[0..(RANK_PERCENTS.index(x))].inject(:+)}
  LEAGUES = [
    "Grand Master",
    "Master",
    "Diamond",
    "Platinum",
    "Gold",
    "Silver",
    "Bronze"
  ]

  VALID_WORDS = %w{autistlist autist rank autistrank topautist toprank}
  MODS = %w{iliedaboutcake hephaestus 13hephaestus bot destiny ceneza sztanpet}.map{|m| m.downcase}
  CACHE_DURATION = 240 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @now = Time.now
    @agent = Mechanize.new
    @last_message = ""
  end
  def check(query)
    @now = Time.now
    m = trycheck(query)
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus or iliedaboutcake something broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    saved_filter = getcached("chat_filter") || []

    # get target
    parts = query.split(' ')
    parts.delete_at(0) # get rid of command
    target = parts.length == 0 ? @chatter : parts.first
    pronoun = target == @chatter ? "you\'re" : "they\'re"

    # load list
    cached = getcached('autist_list')

    if cached.nil? or cached["date"] < Time.now.to_i - CACHE_DURATION    
      begin
        page = @agent.get(get_endpoint)
        full = page.links_with(href: /txt/)
        all = full.map{|a| a.text.gsub(".txt", "")}
        jsn = {
          "all" => all,
          "date" => Time.now.to_i
        }        
        setcached(ENDPOINT, jsn)
      rescue Exception => e
        puts "Problem loading OverRustleLogs.net"
      end
    else
      jsn = cached
    end

    # calculate rank
    index = jsn["all"].index(target)
    if index.nil?
      return "#{target} is missing from the list for some reason. You probably typed their name wrong. This is might be also an error. Maybe the cache is bad?"
    else
      rank = index + 1
      percentile = 100.00 * (rank.to_f / jsn["all"].length)
      league = LEAGUES.fetch(PERCENTILES.index(PERCENTILES.find{|x| x >= percentile}))
      if rank == 0
        behind = "Congratulations #{pronoun} set to be the Top Autist of #{@now.strftime('%B %Y')}!"
      else
        behind = "(right behind "
        behind << jsn["all"][index-1]
        behind << ")"
      end
      output = "#{target} Rank ##{rank} and #{league} league. #{behind}"
    end

    # it's too similar. so it will get the bot banned
    # get the next 3
    if @last_message == output
      if rank > 3
        output = "#{target} is behind "
        output << jsn["all"][index-1]
        output << ", "
        output << jsn["all"][index-2]
        output << ", and "
        output << jsn["all"][index-3]
      else
        output << "SoDoge #{target}, #{pronoun} a top 3 Grand Master autist, rank #{rank}"
      end
    end
    output << " via #{get_endpoint}"
    return output
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
