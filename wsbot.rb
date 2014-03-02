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
  "Cookie" => "sid=72b67fdbf9cb1ce2ffb5d2e8fcfb7443; rememberme=%7B%22expire%22%3A1396165082%2C%22created%22%3A1393573082%2C%22token%22%3A%22869ce5675adb26f82fad8f11d5045e61%22%7D; __utma=101017095.1366955240.1393573035.1393573035.1393573035.1; __utmb=101017095.4.10.1393573035; __utmc=101017095; __utmz=101017095.1393573035.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)",
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
            p "!!! SENDING DATA !!! #{result}"
          else
            # p "nothing to send for #{p_message}"
          end
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