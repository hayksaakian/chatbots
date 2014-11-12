require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class Notes
  VALID_WORDS = %w{help set release transfer}
  RATE_LIMIT = 7 # seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/commands/"

  def initialize
    @last_message = ""
  end
  def regex
    words = getcached('commands') || []
    re = /^!(#{(VALID_WORDS+words).join('|')})/i
    return re
  end
  def set_chatter(name)
    @chatter_name = name
  end
  def check(query)
    m = trycheck(query)
    if @last_message.similar(m) >= 97
      # it's too similar. so it will get the bot banned
      m = "I already just said that, #{@chatter_name}. "
      m << %w{MotherFuckinGame UWOTM8 NoTears CallCatz}.sample
    end
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus something broke with notes/commands. Exception: #{m.to_s}"
  end
  def trycheck(query)
    # if jester is setting the number
    parts = query.split(' ')
    command = parts[0] # eg the first part of their message is a user defined command
    command.slice!(0) # remove leading !
    if command == 'help'
      return "set a command: `!set COMMAND MESSAGE`. call a command: `!COMMAND`. release a command: `!release COMMAND`. transfer a command `!transfer NEW_OWNER_NAME`"
    elsif %w{set release transfer}.include?(command)
      # !set animu check out the animue here: google.com

      if parts.length < 2
        return "#{@chatter_name}, you did it wrong. see !help"
      end
      keyword = parts[1]
      note = getcached("commands_#{keyword}")

      # release
      # !release animu
      if command == 'release'
        if note == nil
          return "#{@chatter_name}, you cannot release an unclaimed command like #{keyword}."
        elsif note['owner'] == @chatter_name
          deletecached("commands_#{keyword}")
          return "#{@chatter_name}, you no longer control #{keyword}"
        else
          return "#{@chatter_name}, you are not allowed to release #{keyword}"
        end
      end

      # unclaimed
      if parts.length < 3
        return "#{@chatter_name}, you did it wrong. see !help"
      end
      if note == nil || note['owner'] == @chatter_name
        if note == nil
          is_new = true
          note = {}
        end
        if command == 'transfer'
          new_owner = parts[2]
          note['owner'] = new_owner
          note['message'] ||= "#{@chatter_name} gave #{new_owner} this command without setting a message"
        else
          message = query.partition(keyword).last.strip
          note['owner'] = @chatter_name
          note['message'] = message
        end
        setcached("commands_#{keyword}", note)
        all_commands = getcached('commands') || []
        all_commands << keyword
        setcached('commands', all_commands)
        return "!#{keyword} (owned by #{@chatter_name}) will now make me say: #{message}"
      else
        return "#{note['owner']} owns this command. gtfo #{@chatter_name}"
      end
    else
      note = getcached("commands_#{command}")
      if note == nil
        return "No one has claimed !#{command} yet. see !help for more info #{@chatter_name}"
      else
        return "#{note['owner']}: #{note['message']}"
      end
    end
  end

  # safe cache! won't die if the bot dies
  def getcached(url)
    return @cached_json if !@cached_json.nil?
    path = CACHE_FILE + hashed(url) + ".json"
    if File.exists?(path)
      f = File.open(path)
      return JSON.parse(f.read)
    end
    return nil
  end
  def setcached(url, jsn)
    @cached_json = jsn
    path = CACHE_FILE + hashed(url) + ".json"
    File.open(path, 'w') do |f2|
      f2.puts JSON.unparse(jsn)
    end
  end
  def deletecached(url)
    path = CACHE_FILE + hashed(url) + ".json"
    if File.exists?(path)
      return File.delete(path)
    end
    return nil
  end

  def hashed(url)
    return Digest::MD5.hexdigest(url).to_s
  end
end