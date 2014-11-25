require 'action_view'
require 'active_support/core_ext/numeric/time'
require 'redditkit'
require 'similar_text'

class Reddit
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::TextHelper

  VALID_WORDS = %w{reddit}
  RATE_LIMIT = 16.seconds
  CACHE_DURATION = 60.seconds
  REDDIT_USER = 'NeoDestiny'
  COMMENT_LENGTH = 256

  attr_accessor :regex

  def initialize
    #Login not required for this
    #RedditKit.sign_in ENV['REDDIT_USER'], ENV['REDDIT_PASS']
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @cached = {}
    @last_message = ""
  end

  def set_chatter(name)
    @chatter = name
  end

  def check(query)
    msg = trycheck(query)
    if @last_message.similar(msg) >= 97
      msg = "Scroll up #{@chatter}, i just said it"
    end
    @last_message = msg
    return msg
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " WhoahDude Tell hephaestus something broke with !reddit. Exception: #{m.to_s}"
  end

  def trycheck(query)
    if @cached[:date].blank? || @cached[:date] < CACHE_DURATION.ago
      comment = RedditKit.user_content(REDDIT_USER, category: 'comments', limit: 1).first
      @cached = { date: Time.now, comment: comment }
    else
      comment = @cached[:comment]
    end

    format(comment)
  end

  def format(comment)
    msg = pluralize(comment.score, 'point') + " "
    msg << tweet_time_ago(comment.created_at) + " ago: "
    msg << HTMLEntities.new.decode(comment.body).truncate(COMMENT_LENGTH, separator: ' ')
  end

  def tweet_time_ago(from_time, to_time = Time.now)
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time   = to_time.to_time   if to_time.respond_to?(:to_time)

    distance_in_minutes = (((to_time - from_time).abs)/60).round
    distance_in_seconds = ((to_time - from_time).abs).round

    case distance_in_minutes
      when 0..1
        case distance_in_seconds
          when 0..59 then "#{distance_in_seconds}s"
          else            "1m"
        end
      when 2..59    then "#{distance_in_minutes}m"
      when 60..1439 then "#{(distance_in_minutes.to_f / 60.0).round}h"
      else
        distance_of_time_in_words(from_time, to_time)
    end
  end
end
