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
  VALID_WORDS = %w{stream strim overrustle OverRustle enable_strims disable_strims}
  MODS = %w{iliedaboutcake hephaestus 13hephaestus bot destiny ceneza sztanpet righttobeararmslol}.map{|m| m.downcase}
  FILTERED_STRIMS = %w{clickerheroes s=advanced strawpoii}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  LINE_WIDTH = 57
  WCHAR = "_"
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"
  WEIRD_NAMES = {
    'youtube-playlist' => 'l',
    'twitch-vod' => 'v',
    'nsfw-chaturbate' => 'n'
  }

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
    @chatter = ""
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
    output = ""
    saved_filter = getcached("chat_filter") || []
    # if MODS.include?(@chatter.downcase) 
    #   if query =~ /^(!(enable_strims|disable_strims))/i
    #     self.strims_enabled = !(query =~ /^(!enable_strims)/i).nil?
    #     word = self.strims_enabled ? 'enabled' : 'disabled'
    #     # true if it's !enable, false otherwise
    #     return "!strims #{word} by #{@chatter}"
    #   end
    # end
    begin
      apid = getjson("https://api.twitch.tv/kraken/streams/destiny")
      if !apid.nil? and apid.has_key?('stream')
        if !apid['stream'].nil?
          output = "Destiny is live at destiny.gg/bigscreen playing #{apid['stream']['game']} for #{apid['stream']['viewers'].to_s} viewers, !strims is disabled until Destiny goes offline"
          self.strims_enabled = false
        elsif apid['stream'].nil? and self.strims_enabled == false
          self.strims_enabled = true
        end
      end
      return output if !self.strims_enabled
    rescue Exception => e
      puts e.message
      puts e.backtrace.join("\n")
      output << "(problems with twitch api) "
    end

    # TODO: don't return anything if destiny is live
    output << "Top 3 OverRustle.com strims: "
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
      else
        if jsn.key?('metaindex') and jsn['metaindex'].key?(sl[0])
          metakey = jsn['metaindex'][sl[0]]
          if jsn['metadata'].key?(metakey)
            md = jsn['metadata'][metakey]
            to_remove << i if (md.key?('live') and md['live'] == false)
          end
        end
      end
    end
    # go from back to front so the index doesn't mess up
    to_remove.reverse.each{|tr| list_of_lists.delete_at(tr)}
    # puts list_of_lists
    # map to sexy urls
    short_domain = "rustle.club"
    list_of_lists = list_of_lists.map do |sl|
      u = URI.parse(sl[0])
      # puts u.path
      parts = u.query.split('&')
      if u.path == '/channel'
        channel = ""
        parts.each do |pt|
          kvs = pt.split("=")
          channel = kvs[1] if kvs[0] == 'user'
        end
        sl[0] = "#{short_domain}/#{channel}"
      elsif u.path == '/destinychat'
        mk = jsn['metaindex'][sl[0]]
        md = jsn['metadata'][mk]
        next if md.nil? 
        platform = md['platform']
        platform = WEIRD_NAMES[platform.downcase] ? platform.downcase : md['platform'][0]

        sl[0] = "#{short_domain}/#{platform}/#{md['channel']}"
      end
      # puts sl
      sl
    end

    list_of_lists.take(3).each do |sl|
      _op = "\n#{sl[0]} has #{sl[1]} | "
      to_add = LINE_WIDTH - _op.length
      if to_add > 0
        _op << to_add.times.map{|x| WCHAR}.join
      end
      output << _op
    end
    if list_of_lists.length > 3
      wildcard = list_of_lists.drop(3).sample
      output << " \nWild Card - #{wildcard[0]}"
    end

    # it's too similar. so it will get the bot banned
    # get the next 3
    if @last_message.similar(output) >= 90
      output = "Top 3 via Overrustle.com/strims #3 to #1 :"
      list_of_lists.take(3).reverse.each do |sl|      
        _op = "\n#{sl[0]} has #{sl[1]} | "
        to_add = LINE_WIDTH - _op.length
        if to_add > 0
          _op << to_add.times.map{|x| WCHAR}.join
        end
        output << _op
      end
    end

    # if @last_message.similar(output) >= 80
    #   output = "\nCheck out Overrustle.com/strims for more strims. RustleBot by hephaestus."
    # end

    return output
  end

  def getjson(url)
    use_ssl = url.index("https") == 0
    url = URI.parse(url)
    content = Net::HTTP.start(url.host, use_ssl: use_ssl, ssl_version: 'SSLv3', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.get url.request_uri
    end
    return JSON.parse(content.body)
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
