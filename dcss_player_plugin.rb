#!/usr/bin/ruby
require 'cinch'

require_relative 'dcss_player'

FETCHER = DcssPlayer.new
RE = DcssPlayer.get_longer_commands.join("|")

class DcssPlayerPlugin
  include Cinch::Plugin
  match /(#{RE}|[A-Z])/i

  def check(query)
    return FETCHER.check(query)
  end

  def execute(m, query)
    if FETCHER.ready
      result = check(p_message)
      if !result.nil? and result.length > 0
        result << suffix
        m.reply result
        p "!!! SENDING DATA !!!"
      end
    end
  end
end