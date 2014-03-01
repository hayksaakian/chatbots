#!/usr/bin/ruby
require 'bundler/setup'
Bundler.require

require_relative 'dcss_player_plugin'

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.freenode.net"
    c.nick = "DCSSBot"
    c.channels = ["#cinch-bots"]
    # c.server = "irc.twitch.tv"
    # c.nick = "1337hephaestus"
    # # c.user = "1337hephaestus"
    # c.password = ENV['TWITCH_OAUTH_TOKEN']
    # c.channels = ["#twitchplayspokemon"]
    c.plugins.plugins = [DcssPlayerPlugin]
  end
end

bot.start
