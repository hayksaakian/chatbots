#!/usr/bin/ruby
require 'bundler/setup'
Bundler.require

require_relative 'dcss_player_plugin'

bot = Cinch::Bot.new do
  configure do |c|
    # c.server = "irc.freenode.net"
    # c.nick = "DogeBot"
    # c.channels = ["#cinch-bots"]
    c.server = "irc.twitch.tv"
    c.nick = "1337hephaestus"
    c.password = ENV[TWITCH__OAUTH_TOKEN]
    c.channels = ["#1337hephaestus"]
    c.plugins.plugins = [DcssPlayerPlugin]
  end
end

bot.start
