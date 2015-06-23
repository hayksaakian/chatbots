require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class Evaluator
  MODS = %w{hephaestus 13hephaestus}.map{|m| m.downcase}
  VALID_WORDS = %w{eval ruby irb}

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
  end
  def check(query)
    m = trycheck(query)
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus something broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    return if !MODS.include?(@chatter.downcase)
    parts = query.split(' ')
    parts.delete_at(0)
    return "/me #{eval(parts.join(' '))}"
  end
end