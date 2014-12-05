require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class Moderation
  VALID_WORDS = %w{blacklist_nospace ignore unignore unblacklist status_api}
  MODS = %w{iliedaboutcake hephaestus 13hephaestus bot destiny ceneza sztanpet}.map{|m| m.downcase}
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
    @chatter = ""
  end
  def ignored?(name)
    thelist = self.baddies || []
    return thelist.include?(name)
  end
  def safe?(line)
    thelist = self.chat_filter || []
    thelist.each do |l|
      return false if line =~ /#{l}/i
    end
    return true
  end
  def check(query)
    m = trycheck(query)
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus RustleBot moderation broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    if MODS.include?(@chatter.downcase)
      parts = query.split(' ')
      if query =~ /^(!status_api)/i
        start_time = Time.now
        resp = open("http://api.overrustle.com/api")
        content = resp.read
        request_duration = Time.now - start_time
        request_duration = (request_duration.round(3)*1000).round
        jsn = JSON.parse(content)
        output = "api.overrustle.com Status: #{jsn['viewercount']} viewers, #{jsn['idlecount']} idlers, #{jsn['connections']} connections, #{resp.meta['age']} cache age, #{request_duration}ms request duration "
        output << %w{DANKMEMES SoDoge Klappa MLADY WORTH DappaKappa}.sample
        return output
      elsif query =~ /^(!blacklist_nospace)/i
        saved_filter = self.chat_filter || []
        if parts.length < 3
          return "#{@chatter} didn\'t format the blacklist command correctly"
        end
        thing_to_blacklist = parts[1] + parts[2]
        saved_filter.push(thing_to_blacklist)
        self.chat_filter = saved_filter
        return "#{parts[1]} #{parts[2]} (no space) added to blacklist by #{@chatter}"
      elsif query =~ /^(!unblacklist)/
        saved_filter = self.chat_filter || []
        if parts.length < 2
          return "#{@chatter} didn\'t format the blacklist command correctly"
        end
        saved_filter.delete(parts[1])
        self.chat_filter = saved_filter
        return "#{parts[1]} removed from the blacklist by #{@chatter}"
      elsif query =~ /^(!(ignore|unignore))/i
        saved_list = self.baddies || []
        if parts.length < 2
          return "#{@chatter} didn\'t format the ignore or unignore command correctly"
        end
        if query =~ /^(!ignore)/i
          saved_list.push(parts[1])
          self.baddies = saved_list
          return "/me is ignoring #{parts[1]} according to #{@chatter}"
        else
          saved_list.delete(parts[1])
          self.baddies = saved_list
          return "/me stopped ignoring #{parts[1]} according to #{@chatter}"
        end
      elsif query =~ /^(!(enable|disable))/i
        saved_list = CHATBOTS || []
        if parts.length < 2
          return "#{@chatter} didn\'t format the enable or disable command correctly"
        end
        bot_name = parts[1]
        if query =~ /^(!disable)/i
          todelete = nil
          # todo: could be .select
          bot = CHATBOTS.delete_if{|cb| (cb.class.name.underscore == bot_name or cb.class.name == bot_name)}
          CHATBOTS.delete(todelete)
          # todo: persist
          return "#{@chatter} disabled #{bot}"
        else
          path = "./#{bot_name.underscore}.rb"
          if File.exists?(path)
            require path 
            CHATBOTS << Object.const_get(bot_name.camelize).new
            return "#{@chatter} enabled #{bot}"
          else
            return "/me could not find a chat bot at #{path}"
          end
        end
      end
    end
    return nil
  end

  def getjson(url)
    content = open(url).read
    return JSON.parse(content)
  end

  def chat_filter
    getcached('chat_filter')
  end
  def chat_filter=(jsn)
    setcached('chat_filter', jsn)
  end

  def baddies
    return getcached('baddies') || []
  end
  def baddies=(jsn)
    setcached('baddies', jsn)
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
