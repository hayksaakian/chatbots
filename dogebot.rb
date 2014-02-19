#!/usr/bin/ruby
require 'bundler/setup'
Bundler.require

require_relative 'dogebot_plugin'

bot = Cinch::Bot.new do
  configure do |c|
    # c.server = "irc.freenode.net"
    # c.nick = "DogeBot"
    # c.channels = ["#cinch-bots"]
    c.server = "irc.rizon.net"
    c.nick = "DogeBot"
    c.channels = ["#destinyecho"]
    c.plugins.plugins = [DogebotPlugin]
  end
end

bot.start