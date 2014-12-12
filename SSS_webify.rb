require 'redd'
require 'imgur'
require 'kramdown'
require 'open-uri'
require 'htmlentities'
require 'liquid'
require 'liquidFilters.rb'

$HTMLEntities = HTMLEntities.new()

module SSSWebify
  def self.webify(submission,posts,to_where='index.html',template='index.liquid')
    # load our template
    File.open( template,"r" ) { |f|
      @template = Liquid::Template.parse(f.read)
    }

    # build variables
    variables = {}
    variables['fullname'] = submission.fullname
    variables['now'] = Time.now.to_s
    variables['submission_title'] = submission.title
    variables['submission_url'] = submission.url
    variables['last_time_after_text'] = time_since(Time.at(submission.created), Time.now())
    variables['last_time_expiry'] = ((Time.at(submission.created) + (60*60*24*7)) - Time.now()).to_i # expire 6 days after post
    variables['posts'] = []

    posts.sort! { |a,b| b[:created_utc].to_i <=> a[:created_utc].to_i }
    posts.each do |post|
      variables['posts'].push(dump_post_liquid(submission, post))
    end
    puts to_where
    # write the output
    File.open( to_where,"w" ) { |html|
      html << @template.render(variables)
    }
  end
  class << self
    private
    def dump_post_liquid(submission, post)
      dump = {}
      if post[:firstline] =~ /\*\*(.{,40}?)\*\*/i then
        dump['title'] = $~[1].to_s
      end
      dump['time_after'] = time_since(Time.at(submission.created), Time.at(post[:created_utc]))
      dump['source'] = post[:source]
      dump['firstimage'] = post[:firstimage]
      if post[:icon].length > 0 then
        dump['firstimage_icon'] = post[:icon]
      end
      dump['url'] = post[:url]
      dump['author'] = post[:author]
      dump['related'] = []
      if post[:twitter_link].length > 0 then
        dump['related'].push({'link' => post[:twitter_link], 'class' => 'twitter', 'icon' => 'fa fa-twitter'})
        dump['twitter_link'] = post[:twitter_link]
        dump['twitter_handle'] = post[:twitter_handle]
      end
      if post[:youtube].length > 0 then
        dump['related'].push({'link' => post[:youtube], 'class' => 'youtube', 'icon' => 'fa fa-youtube-play'})
        dump['youtube'] = post[:youtube]
      end
      # user specified data
      if post[:author] == 'lemtzas' then
        puts post[:body]
      end
      post[:body].scan(/\[.*?\]\(\/botdata\s*?(?:\"|\')(.*?)\:(.*?)(?:\"|\')\)/i) { |directive,data|
        # puts "#{directive} -> '#{data}'"
        case directive
          when 'thumb'
            dump['thumb'] = data
          when 'title'
            dump['title'] = data
          end
      }
      return dump
    end

    def dump_post(submission, post)
      dump = ''
      time = time_since(Time.at(submission.created), Time.at(post[:created_utc]))

      dump <<   %%   <div class='tile'>
                      <a href='#{post[:source]}' class='ss-link' style="background-image: url(#{post[:firstimage]})">%
      if post[:icon].length > 0 then
        dump << %%      <i class="#{post[:icon]}"></i>%
      end
      dump << %%      </a>
                      <div class='top-wrap'>%
      # quick links
      dump << "         <a href='#{post[:url]}' class='reddit'><i class='fa fa-reddit'></i></a>"
      if post[:twitter_link].length > 0 then
        dump << "       <a href='#{post[:twitter_link]}' class='twitter'><i class='fa fa-twitter'></i></a>"
      end
      if post[:youtube].length > 0 then
        dump << "       <a href='#{post[:youtube]}' class='youtube'><i class='fa fa-youtube'></i></a>"
      end

      # nameplate text
      if post[:twitter_link].length > 0 then
        dump << "<a href='#{post[:twitter_link]}'>@#{post[:twitter_handle]}</a>"
      else
        dump << "<a href='#{post[:url]}' class='author'>/u/#{post[:author]}</a>"
      end
      dump << "</div>"

      # time plate
      dump << "      <div class='time-wrap'><span>#{time} after</span></div>"

      # wrap it all up
      dump << "</div>\n\n"
      return dump
    end

    def time_since(first, second)
      if first > second then
        first, second = second, first
      end
      seconds_from_submission = second - first
      time = ""
      if seconds_from_submission > 60*60*24 then
        days = (seconds_from_submission/(60*60*24)).floor
        hours = ((seconds_from_submission - days*(60*60*24))/(60*60)).floor
        time = "#{days}d #{hours}h"
      elsif seconds_from_submission > 60*60 then
        hours = (seconds_from_submission/(60*60)).floor
        minutes = ((seconds_from_submission - (hours*60*60))/60).floor
        time = "#{hours}h #{minutes}m"
      elsif seconds_from_submission > 60
        time = "#{(seconds_from_submission/60).floor}m"
      else
        time = "#{(seconds_from_submission).floor}s"
      end
    end
  end
end
