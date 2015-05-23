require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
require 'parse-ruby-client'
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
  WCHAR2 = "-"
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  SHORT_DOMAIN = "rustle.club"

  attr_accessor :regex, :last_message, :chatter, :shortcuts, :live_changed
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
    @chatter = ""
    @live_changed = false

    @shortcuts = getjson("http://api.OverRustle.com/shortcuts.json").invert
    Parse.init({:application_id => ENV["PARSECOM_APP_ID"],
           :api_key => ENV["PARSECOM_API_KEY"]})
  end
  def check(query)
    m = trycheck(query)
    if @live_changed
      pushdata = { :alert => m, :is_live => !self.strims_enabled }
      push = Parse::Push.new(pushdata, "twitch-_-destiny")
      push.save
    end
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
        lse = self.strims_enabled
        if !apid['stream'].nil?
          output = "Destiny is live at destiny.gg/bigscreen playing #{apid['stream']['game']} for #{apid['stream']['viewers'].to_s} viewers, !strims is disabled until Destiny goes offline"
          self.strims_enabled = false
        elsif apid['stream'].nil? and self.strims_enabled == false
          self.strims_enabled = true
        end
        # safeguard against sending the same message
        # too many times
        # TODO: protect against flip/flopping bugs
        # that cause tons of messages to be sent
        @live_changed = lse != self.strims_enabled
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
    stream_list = jsn['stream_list']
    # filter:
    to_remove = []
    stream_list.each_with_index do |sl, i|
      if sl.key?('name') and sl['name'] =~ /(#{filtered_strims.join('|')})/i
        to_remove << i
      elsif sl.key?('channel') and sl['channel'] =~ /(#{filtered_strims.join('|')})/i
        to_remove << i
      elsif sl.key?('live') and sl['live'] == false)
        to_remove << i 
      end
    end
    # go from back to front so the index doesn't mess up
    to_remove.reverse.each{|tr| stream_list.delete_at(tr)}
    # puts stream_list

    # map to touples of (short_url, viewers)
    snippet_list = stream_list.map do |md|
      sl = []
      if md.key?('name')
        sl[0] = "#{SHORT_DOMAIN}/#{md['name']}"
      elsif md.key?('channel') and md.key?('platform')
        platform = md['platform'].downcase
        platform = @shortcuts[platform] if @shortcuts.key?(platform)
        sl[0] = "#{SHORT_DOMAIN}/#{platform}/#{md['channel']}"
      end
      sl[1] = md['rustlers']
      # puts sl
      sl
    end

    snippet_list.take(3).each do |sl|
      _op = "\n#{sl[0]} has #{sl[1]} | "
      to_add = LINE_WIDTH - _op.length
      if to_add > 0
        _op << to_add.times.map{|x| WCHAR}.join
      end
      output << _op
    end
    if snippet_list.length > 3
      wildcard = snippet_list.drop(3).sample
      output << " \nWild Card - #{wildcard[0]}" unless wildcard.nil?
    end

    # it's too similar. so it will get the bot banned
    # get the next 3
    if @last_message.similar(output) >= 90
      output = "Top 3 via Overrustle.com/strims #3 to #1 "
      snippet_list.take(3).reverse.each do |sl|      
        _op = "\n#{sl[0]} has #{sl[1]} | "
        to_add = LINE_WIDTH - _op.length
        if to_add > 0
          _op << to_add.times.map{|x| WCHAR2}.join
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
