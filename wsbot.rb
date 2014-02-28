require 'faye/websocket'
require 'json'
require 'eventmachine'

# require_relative 'roulette'
# chatbot = Roulette.new

require_relative 'dcss_player'
chatbot = DcssPlayer.new

CMD_REGEX = chatbot.regex

WS_ENDPOINT = 'ws://www.destiny.gg:9998/ws'
PROTOCOLS = nil
# note cookie lasts 1 month, look into using API somehow
OPTIONS = {headers:{
  "Cookie" => "__utma=16313635.1862555919.1372040766.1372040766.1372040766.1; __utmc=16313635; sid=de56151115cd77154d5c8f231880a28a; rememberme=%7B%22expire%22%3A1396164242%2C%22created%22%3A1393572242%2C%22token%22%3A%22869a1e12c83bc324b0b649e010aacae2%22%7D; __utma=101017095.2025998726.1387259362.1393438259.1393572259.80; __utmb=101017095.1.10.1393572259; __utmc=101017095; __utmz=101017095.1390253874.38.4.utmcsr=reddit.com|utmccn=(referral)|utmcmd=referral|utmcct=/r/Destiny/",
  "Origin" => "*"
  }}

reconnects = 0
# puts chatbot.trycheck("")

EM.run {
  ws = Faye::WebSocket::Client.new(WS_ENDPOINT, PROTOCOLS, OPTIONS)

  ws.on :open do |event|
    p [:open]
    reconnects = 0
    # ws.send('Hello, world!')
  end

  ws.on :message do |event|
    p [:message, event.data]
    # used to 
    if event.data.nil?
      p [:error, event.to_s]
    elsif event.data.match /^PING/
      ws.send("PONG "+event.data[5..event.data.length])
    elsif event.data.match /^(ERR|MSG)/
      suffix = ""
      p_message = ""
      if event.data.match /^ERR/
        if event.data.match /duplicate/
          # suffix = " OverRustle x #{(Random.rand*100000).to_s}"
        end
      else
        # removes their name from the message, i think?
        proper_message = event.data.split(" ")
        proper_message.shift
        proper_message = proper_message.join(" ")
        parsed_message = JSON.parse(proper_message)
        p_message = parsed_message["data"]
      end
      if !p_message.nil? and p_message.is_a?(String) and p_message.match(CMD_REGEX)
        if chatbot.ready
          result = chatbot.check(p_message)
          if !result.nil? and result.length > 0
            result << suffix
            jsn = {data: result}
            ws.send("MSG "+jsn.to_json)
            p "!!! SENDING DATA !!!"
          else
            p "nothing to send for #{p_message}"
          end
        else
        end
      end
    end
  end

  ws.on :close do |event|
    p [:close, event.code, event.reason]
    ws = nil
    if event.code = 1006 and reconnects < 4
      sleep 1
      reconnects += 1
      ws = Faye::WebSocket::Client.new(WS_ENDPOINT, PROTOCOLS, OPTIONS)
    end
  end

  ws.on :event do |event|
    p event
  end
}