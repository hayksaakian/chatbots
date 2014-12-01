require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class OverrustleFetcher
  ENDPOINT = "http://api.overrustle.com/api"
  VALID_WORDS = %w{strim strims overrustle OverRustle status_api enable_strims disable_strims}
  MODS = %w{iliedaboutcake hephaestus 13hephaestus bot destiny ceneza sztanpet}.map{|m| m.downcase}
  FILTERED_STRIMS = %w{clickerheroes s=advanced strawpoii}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
    @chatter = ""
  end
  def set_chatter(name)
    @chatter = name
  end
  def check(query)
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
    if MODS.include?(@chatter.downcase) 
      if query =~ /^(!status_api)/i
        start_time = Time.now
        resp = open(ENDPOINT)
        content = resp.read
        request_duration = Time.now - start_time
        request_duration = (request_duration.round(3)*1000).round
        jsn = JSON.parse(content)
        output = "api.overrustle.com Status: #{jsn['viewercount']} viewers, #{jsn['idlecount']} idlers, #{jsn['connections']} connections, #{resp.meta['age']} cache age, #{request_duration}ms request duration "
        output << %w{DANKMEMES SoDoge Klappa MLADY WORTH DappaKappa}.sample
        return output
      elsif query =~ /^(!(enable_strims|disable_strims))/i
        self.strims_enabled = !(query =~ /^(!enable_strims)/i).nil?
        word = self.strims_enabled ? 'enabled' : 'disabled'
        # true if it's !enable, false otherwise
        return "!strims #{word} by #{@chatter}"
      end
    end

    if self.strims_enabled == false
      output = "!strims is currently disabled, but #{@chatter} called it anyway"
      puts output
      return output if MODS.include?(@chatter.downcase)
      return nil
    end
    # TODO: don't return anything if destiny is live
    output = "Top 3 OverRustle.com strims: "
    # cached = getcached(ENDPOINT)
    # expire cache if...
    jsn = getjson(ENDPOINT)

    filtered_strims = FILTERED_STRIMS + saved_filter
    strims = jsn["streams"]
    list_of_lists = strims.sort_by{|k,v| -(v).to_i}
    # filter:
    to_remove = []
    list_of_lists.each_with_index do |sl, i|
      if sl[0] =~ /(#{filtered_strims.join('|')})/i
        to_remove << i
      end
    end
    # go from back to front so the index doesn't mess up
    to_remove.reverse.each{|tr| list_of_lists.delete_at(tr)}
    # puts list_of_lists
    # map to sexy urls
    short_domain = "api.overrustle.com"
    list_of_lists = list_of_lists.map do |sl|
      u = URI.parse(sl[0])
      # puts u.path
      if !['/destinychat', '/channel'].include?(u.path)
        sl[0] = "overrustle.com" + sl[0]
      else
        parts = u.query.split('&')
        if u.path == '/channel'
          channel = ""
          parts.each do |pt|
            kvs = pt.split("=")
            channel = kvs[1] if kvs[0] == 'user'
          end
          sl[0] = "#{short_domain}/#{channel}"
        elsif u.path == '/destinychat'
          channel = ""
          platform = ""
          parts.each do |pt|
            kvs = pt.split("=")
            platform = kvs[1] if kvs[0] == 's'
            channel = kvs[1] if kvs[0] == 'stream'
          end
          platform = platform == 'twitch-vod' ? 'v' : platform[0]
          sl[0] = "#{short_domain}/#{platform}/#{channel}"
        end
      end
      # puts sl
      sl
    end

    list_of_lists.take(3).each do |sl|
      output << "\n#{sl[0]} has #{sl[1]} | "
    end
    if list_of_lists.length > 3
      wildcard = list_of_lists.drop(3).sample
      output << " \nWild Card - #{wildcard[0]}"
    end

    # it's too similar. so it will get the bot banned
    # get the next 3
    if @last_message.similar(output) >= 90
      output = "Full Strim List - overrustle.com/strims"
      output << " #4 to #6  :"
      list_of_lists.drop(3).take(3).each do |sl|
        output << " \n#{sl[0]} has #{sl[1]} | "
      end
    end

    if @last_message.similar(output) >= 80
      output = "\nCheck out Overrustle.com/strims for more strims. RustleBot by hephaestus."
    end

    return output
  end

  def getjson(url)
    content = open(url).read
    return JSON.parse(content)
  end

  def strims_enabled
    v = getcached('strims_enabled')
    # set default
    if v.nil? 
      self.setcached('strims_enabled', {'enabled' => true})
      v = self.getcached('strims_enabled')
    end
    return v['enabled']
  end

  def strims_enabled=(bool)
    # coerce to bool because doriots
    bool = (bool == true)
    setcached('strims_enabled', {'enabled' => bool})
  end

  # safe cache! won't die if the bot dies
  def getcached(url)
    _cached = instance_variable_get "@cached_#{hashed(url)}"
    return _cached unless _cached.nil?
    path = CACHE_FILE + "#{hashed(url)}.json"
    if File.exists?(path)
      File.open(path, "r:UTF-8") do |f|
        _cached = JSON.parse(f.read)
        instance_variable_set("@cached_#{hashed(url)}", _cached)
        return _cached
      end 
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
