#!/usr/bin/ruby
require 'bundler/setup'
Bundler.require

VALID_KEYS = %w{a b up down left right start select}
ECHO_USER = "II"

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.rizon.net"
    c.nick = "ChatGameBot"
    c.channels = ["#destinyecho"]
  end

  on :message, // do |m|
    message = m.message.downcase
    if m.user.nick == ECHO_USER
      parts = message.split(" ")
      parts.shift
      message = parts.first
      if VALID_KEYS.include?(message)
        `echo "#{message}" >> log.txt`
      end
    end
  end
end

bot.start