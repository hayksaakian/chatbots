#!/usr/bin/ruby
require 'cinch'

require_relative 'dcss_player'

FETCHER = DcssPlayer.new

class DcssPlayerPlugin
  include Cinch::Plugin
  match FETCHER.regex

  def check(query)
    FETCHER.check(query)
  end

  def execute(m, query)
    if FETCHER.ready
      result = FETCHER.check(p_message)
      if !result.nil? and result.length > 0
        result << suffix
        m.reply result
        p "!!! SENDING DATA !!!"
      end
    end
  end
end