require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class Cardstone
  ENDPOINT = "http://bit.ly/1vQhPkl"
  VALID_WORDS = %w{overlay tracker}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"
  COOLDOWN = 20

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /(overlay|tracker|^!(#{VALID_WORDS.join('|')}))/i
    @last_message = ""
    @last_time = Time.at(0)
    @last_one = 0
  end
  def check(query)
    return trycheck(query)
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus something broke with cardstone. Exception: #{m.to_s}"
  end
  def pickone
    phrases = [
      "Destiny is using #{ENDPOINT} ! Click \'101 releases\' and download the top release if you want to try it out",
      "The overlay on screen is #{ENDPOINT}",
      "The tracker is HearthstoneDeckTracker #{ENDPOINT}",
      "#{ENDPOINT} is what Destiny is using to track his cards, no it isn\'t cheating, would he use it on stream if it was?"
    ]

    @last_one = 0 if @last_one >= phrases.length
    phrase = phrases[@last_one]
    @last_one = @last_one + 1
    return phrase
  end
  def trycheck(query)
    puts Time.now - @last_time
    if (Time.now - @last_time) > COOLDOWN
      @last_time = Time.now
      output = pickone
      return output
    else
      puts 'bad check'
      return nil
    end
  end
end
