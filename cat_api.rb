require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class CatApi
  ENDPOINT = "http://thecatapi.com/api/images/get"
  VALID_WORDS = %w{randomcat randomkingsly KINGSLY MotherFuckinGame CallCatz}

  attr_accessor :regex, :last_message
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
  end
  def check(query)
    m = trycheck(query)
    # if it's too similar it will get the bot banned
    m = check(query) if m == @last_message
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    "KINGSLY Uh oh... Tell hephaestus !randomcat broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    r = Net::HTTP.get_response(URI.parse(ENDPOINT))
    output = %w{KINGSLY MotherFuckinGame CallCatz DappaKappa DuckerZ DestiSenpaii}.sample
    output << " #{r['location']}"
    return output
  end
end