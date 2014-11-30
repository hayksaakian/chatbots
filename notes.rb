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
  VALID_WORDS = %w{help set release transfer commands mycommands}
  WHITELISTED_USERS = %w{hephaestus iliedaboutcake righttobeararmslol destiny sztanpet ceneza mikecom32}
  RATE_LIMIT = 7 # seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/commands/"

  def initialize
    @last_message = ""
  end
  def regex
    words = getcached('commands')
    words ||= []
    words = words.map{|wd| wd['command']}
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
      m = "I literally just said that, #{@chatter_name}. "
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
    command = parts[0].downcase # eg the first part of their message is a user defined command
    command.slice!(0) # remove leading !
    if command == 'help'
      return "set a command: `!set COMMAND MESSAGE`. call a command: `!COMMAND`. release a command: `!release COMMAND`. transfer a command `!transfer COMMAND NEW_OWNER_NAME`"
    elsif %w{set release transfer}.include?(command)
      # !set animu check out the animue here: google.com

      if parts.length < 2
        return "#{@chatter_name}, you did it wrong. see !help"
      end
      keyword = parts[1].downcase
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
      whitelisted = WHITELISTED_USERS.include?(@chatter_name.downcase)
      if note == nil or note['owner'] == @chatter_name or whitelisted
        if note == nil
          is_new = true
          note = {}
          unless whitelisted
            return "You must be whitelisted to set new commands"
          end
        end
        if command == 'transfer'
          new_owner = parts[2]
          note['owner'] = new_owner
          note['message'] ||= "#{@chatter_name} gave #{new_owner} this command without setting a message"
        elsif command == 'set'
          message = query.partition(/(#{keyword})/i).last.strip
          note['owner'] = @chatter_name
          note['message'] = message
        end
        note['command'] ||= keyword

        setcached("commands_#{keyword}", note)
        all_commands = getcached('commands')
        all_commands ||= []
        # TODO: don't insert the same command twice
        all_commands << note
        setcached('commands', all_commands)

        if command == 'transfer'
          return "#{@chatter_name} transfered !#{keyword} to #{note['owner']}"
        else
          return "Now, !#{keyword} says what #{@chatter_name} just said"
        end
      else
        return "#{note['owner']} owns this command. gtfo #{@chatter_name}"
      end
    elsif %w{mycommands commands}.include?(command)
      all_commands = getcached('commands')
      all_commands ||= []
      preput = ""
      if command == "mycommands"
        all_commands.select!{|c| c['owner']==@chatter_name}
        preput = "#{@chatter_name}\'s commands (prefix with !):"
      else
        preput = "All Commands (prefix with !):"
      end
      all_commands.map!{|c| c['command']}
      # TODO: this is a bug, we should be deduping commands
      all_commands.uniq!
      return "#{preput} #{all_commands.join(', ')}"
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
    _cached = instance_variable_get "@cached_#{hashed(url)}"
    return _cached unless _cached.nil?
    path = CACHE_FILE + "#{url}.json"
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
    path = CACHE_FILE + "#{url}.json"
    File.open(path, 'w') do |f2|
      f2.puts JSON.unparse(jsn)
    end
  end
  def deletecached(url)
    path = CACHE_FILE + hashed(url) + ".json"
    instance_variable_set("@cached_#{hashed(url)}", nil)
    if File.exists?(path)
      return File.delete(path)
    end
    return nil
  end

  def hashed(url)
    return Digest::MD5.hexdigest(url).to_s
  end
end