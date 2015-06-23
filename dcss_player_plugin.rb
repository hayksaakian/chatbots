#!/usr/bin/ruby
require 'cinch'

require_relative 'dcss_player'

FETCHER = DcssPlayer.new
RE = FETCHER.get_regex

class DcssPlayerPlugin
  include Cinch::Plugin
  match RE, use_prefix: false

  def check(query)
    return FETCHER.check(query)
    # query
  end

  def execute(m)
    query = m.message
    if FETCHER.ready
      result = check(query)
      if !result.nil? and result.length > 0
        # m.reply result
        p "!!! SENDING DATA !!!"
      end
    end
  end
end