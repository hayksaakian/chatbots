#!/usr/bin/ruby
Encoding.default_external = "utf-8"
require 'rubygems'
require 'faye/websocket'
require 'json'
require 'cgi'
require 'net/http'
require 'eventmachine'
require 'dotenv'
require 'similar_text'
Dotenv.load

puts "ARGS: #{ARGV.map{|a| a.to_s}.join(', ')}"

DESTINYGG_API_KEY = (ARGV.length > 0 and !ARGV[0].nil? and ARGV[0].length > 0) ? ARGV[0] : ENV['DESTINYGG_API_KEY']
WS_ENDPOINT = (ARGV.length > 1 and !ARGV[1].nil? and ARGV[1].length > 0) ? "ws://#{ARGV[1]}/ws" : ENV.fetch('DESTINYGG_WS_ENDPOINT', 'ws://www.destiny.gg:9998/ws')

# require_relative 'roulette'
# chatbot = Roulette.new

# require_relative 'dcss_player'
# chatbot = DcssPlayer.new

CLASSES = %w{
  overrustle_fetcher 
  jester 
  csgo_stats 
  moobie 
  reddit 
  cat_facts 
  evaluator
  fortune
  chance
  lol_stats
  notes
}

CLASSES.each do |c|
  require_relative c
end
require_relative 'moderation'

MODERATION = Moderation.new

# todo make the chatbot classes mutable
CHATBOTS = CLASSES.map{|c| Object.const_get(c.camelize).new}

CHATBOTS << MODERATION

puts CHATBOTS

PROTOCOLS = nil

RATE_LIMIT = ENV.fetch('RATE_LIMIT', 14) # seconds
ENV['last_time'] = '0'

# TODO come up with a smarter throttle
# that allows calls via whispers more often
# without enabling whispers to dodge all throttling
def ready(command, opts={})
  now = Time.now.to_i
  if (command != GLOBALS['last_command']) or (now - ENV['last_time'].to_i > RATE_LIMIT)
    ENV['last_time'] = now.to_s
    GLOBALS['last_command'] = command
    return true
  end
  return false
end

# constants for marking as read
# this is a hack until there is a consistent way to produce
# cookies with an sid value and a valid token
DESTINY_COOKIE = ENV['RAW_DGG_COOKIE']
# DESTINY_COOKIE = CGI::Cookie.new('authtoken', DESTINYGG_API_KEY.to_s)

# constants for the websocket server
OPTIONS = {headers:{
  "Cookie" => "authtoken=#{DESTINYGG_API_KEY};",
  "Origin" => "*"
  }
}

GLOBALS = {
  'reconnects' => 0,
  'baddies' => [], # todo: persist this
  'last_command' => '',
  'last_message' => ''
}

module MyKeyboardHandler
  def receive_data keystrokes
    if keystrokes == "\n"
      message = GLOBALS['keystrokes']
      cmd = "MSG"
      parts = message.split(' ')
      if message[0] == '/' 
        if ['/whisper', '/notify'].include?(parts[0])
          parts[0] = "/notify"
          cmd = parts.shift
          cmd.upcase!
          cmd[0] = ""
          jsn = {data: parts.join(' '), nick: parts[0]}
        elsif parts[0] != '/me'
          cmd = parts.shift
          cmd.upcase!
          cmd[0] = ""
          jsn = {data: parts.join(' ')}
        end
      else
        jsn = {data: message}
      end
      message = "#{cmd} "+jsn.to_json
      GLOBALS['ws'].send(message) 
      GLOBALS['keystrokes'] = ""
      # puts "sending #{message}"
    else
      GLOBALS['keystrokes'] = "" if GLOBALS.has_key?('keystrokes') == false
      GLOBALS['keystrokes'] << keystrokes
    end
    # puts "I received the following data from the keyboard: #{keystrokes}"
  end
end

EM.run {
  def make_ws
    ws = Faye::WebSocket::Client.new(WS_ENDPOINT, PROTOCOLS, OPTIONS)

    ws.on :open do |event|
      p [:open]
      GLOBALS['reconnects'] = 0
    end

    ws.on :message do |event|
      p [:message, event.data]
      # used to 
      if event.data.nil?
        p [:error, event.to_s]
      elsif event.data.match /^PING/
        ws.send("PONG "+event.data[5..event.data.length])
      elsif event.data.match /^(ERR|MSG|(PRIVMSG\b))/
        suffix = ""
        p_message = ""
        baderror = false
        if event.data.match /^ERR/
          if event.data.match /duplicate/i
            # suffix = " OverRustle x #{(Random.rand*100000).to_s}"
          elsif event.data.match /needlogin/i
            baderror = true
            puts "---> need login!"
          elsif event.data.match /muted/i
            baderror = true
            puts '---> Muted'
            # this is broken, because it's one person too late
            # MODERATION.check("!ignore #{GLOBALS['last_caller']}")
            # GLOBALS['last_caller'] = ''
          end
        else
          # removes their name from the message, i think?
          proper_message = event.data.split(" ")
          proper_message.delete_at(0)

          proper_message = proper_message.join(" ")
          parsed_message = JSON.parse(proper_message)
          p_message = parsed_message["data"]
          chatter_name = parsed_message["nick"]
        end
        if !baderror and !MODERATION.ignored?(chatter_name) and !parsed_message.nil? and !p_message.nil? and p_message.is_a?(String)
          nothrottle = false
          from_pm = false
          if parsed_message.has_key?('messageid')
            nothrottle = true
            from_pm = true
            # if we got a PM, mark as read!
            read_endpoint = "http://www.destiny.gg/profile/messages/openall"
            uri = URI(read_endpoint)
            read_http = Net::HTTP.new(uri.host, uri.port)
            read_req = Net::HTTP::Post.new(uri.request_uri)
            read_req['Cookie'] = DESTINY_COOKIE.to_s
            read_req['Origin'] = "http://www.destiny.gg"
            response = read_http.request(read_req)
            puts "Tried to Mark as Read. Response: #{response}"
          end
          CHATBOTS.each do |chatbot|
            if p_message.match(chatbot.regex)
              chatbot.from_pm = from_pm if chatbot.respond_to?(:from_pm=)
              if chatbot.respond_to?(:chatter=)
                chatbot.chatter = chatter_name
                puts "set chatter name to #{chatter_name}"
              end
              cmd = p_message.split(' ').first
              # for legacy api
              chatbot.last_message = GLOBALS["last_message"] if chatbot.respond_to?(:last_message=)
              # TODO: replay to the @chatter via whisper 
              # if the same !command is called multiple times quickly 
              result = (nothrottle or ready(cmd)) ? chatbot.check(p_message) : nil
              if !result.nil? and result.length > 0
                result << suffix
                # check for safety
                parts = result.split("\n")
                parts.delete_if{|pt| !MODERATION.safe?(pt)}
                result = parts.join("\n")
                jsn = {}
                if result =~ /^\/(w|n|notify|whisper|t)/ and result.split(' ').length > 2
                  mparts = result.split(' ')
                  jsn[:nick] = mparts[1]
                  mparts.delete_at(0)
                  mparts.delete_at(0)
                  jsn[:data] = mparts.join(' ')
                  ws.send("PRIVMSG "+jsn.to_json)
                else
                  jsn[:data] = result
                  ws.send("MSG "+jsn.to_json)
                end
                p "<--- SENDING DATA !!! #{result}"
                GLOBALS['last_caller'] = chatter_name
                GLOBALS['last_message'] = result
              end
              # if we found a matching bot, stop the loop
              break 
            end
          end
        end
      end
      # s = gets
      # ujsn = {data: s}
      # ws.send("MSG "+ujsn.to_json)
    end

    ws.on :close do |event|
      p [:close, event.code, event.reason]
      ws = nil
      puts 'Disconnected!'
      if (event.code == 1006 or event.code == 1000) and GLOBALS['reconnects'] < 4
        puts 'due to network connection to chat server'
        sleep 2
        GLOBALS['reconnects'] += 1
        make_ws
      end
    end

    ws.on :event do |event|
      p event
    end
    GLOBALS['ws'] = ws
    EM.open_keyboard(MyKeyboardHandler)
  end
  make_ws
}
