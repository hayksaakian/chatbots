require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class Fortune
  VALID_WORDS = %w{8ball fortune}
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"
  ANSWERS = [
    "It is certain",
    "It is decidedly so",
    "Without a doubt",
    "Yes definitely",
    "You may rely on it",
    "As I see it, yes",
    "Most likely",
    "Yes",
    "Yes, in 5 minutes Heimerdonger",
    "NOPE.jpeg",
    "Don\'t count on it",
    "My reply is no",
    "My sources say no",
    "Outlook not so good",
    "Not a chance",
    "Very doubtful",
    "Highly unlikely",
    "Maybe in your imagination"
  ]

  attr_accessor :regex, :last_message, :chatter
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
  end
  def check(query)
    return trycheck(query)
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus something broke with !8ball. Exception: #{m.to_s}"
  end
  def trycheck(query)
    parts = query.split(' ')
    parts.delete_at(0)
    question = parts.join(' ')
    questions = getcached('questions') or {}
    questions.keys.each do |q|
      if q.to_s.similar(questions) > 95
        return questions[q]
      end
    end
    questions[question] = ANSWERS.sample
    setcached('questions', questions)
    return "#{@chatter} #{questions[question]}"
  end

  # safe cache! won't die if the bot dies
  def getcached(url)
    _cached = instance_variable_get "@cached_#{hashed(url)}"
    return _cached unless _cached.nil?
    path = CACHE_FILE + "#{hashed(url)}.json"
    if File.exists?(path)
      f = File.open(path)
      _cached = JSON.parse(f.read)
      instance_variable_set("@cached_#{hashed(url)}", _cached)
      return _cached
    end
    return nil
  end
  def setcached(url, jsn)
    instance_variable_set("@cached_#{hashed(url)}", jsn)
    path = CACHE_FILE + "#{hashed(url)}.json"
    File.open(path, 'w') do |f2|
      f2.puts JSON.unparse(jsn)
    end
  end

  def hashed(url)
    return Digest::MD5.hexdigest(url).to_s
  end
end