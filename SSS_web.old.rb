# http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-thumb100.jpg
# http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-poster.jpg
# https://api.imgur.com/models/image
#   ex: http://i.imgur.com/cQzi1m.jpg
# http://miners.github.io/MinusAPIv2/v2/objects.html

require "rubygems"
require "bundler/setup"
require 'redd'
require 'imgur'
require 'SSS_web_helper.rb'

$imgur = Imgur.new("fdc4613624fff28")

module SubSearch
  # Look for subreddits matching the given query.
  #
  # @param query [String] The search query.
  # @param params [Hash] A hash of parameters to send with the request.
  # @option params [String] :after Return results after the given
  #   fullname.
  # @option params [String] :before Return results before the given
  #   fullname.
  # @option params [Integer] :count (0) The number of items already seen
  #   in the listing.
  # @option params [1..100] :limit (25) The maximum number of things to
  #   return.
  # @return [Redd::Object::Listing] A listing of subreddits.
  def search(query, params = {})
    params[:q] = query
    puts "#{display_name}"
    client.object_from_response :get, "/r/#{display_name}/search.json", params
  end
end

Redd::Object::Subreddit.include(SubSearch)

$redd = Redd::Client::Unauthenticated.new()

$gamedev = $redd.subreddit("gamedev")

submissions = $gamedev.search("flair:SSS",
             {:limit => 1,
              :restrict_sr => true,
              :sort => "new",
              :t => "all" })

def perc(v1,v2)
  (v1*100.0/v2).floor.to_s + "%"
end

$perc2_total = 1
def perc2(v1)
  (v1*100.0/$perc2_total).floor.to_s + "%"
end

$seen = {}

$expanded = {}

def expand(thing)
  was_expanded = true
  while was_expanded == true do
    was_expanded = false
    thing.each do |subthing|
      if subthing.is_a?(Redd::Object::MoreComments) and not $expanded[subthing] then
        subthing.expand()
        $expanded[subthing] = true
        print("'")
        was_expanded = true
      end
    end
  end
end

def limit_lines(text, max)
  endpoint = 0
  [1..max].each do
    endpoint = text.index("\n",endpoint+1) || text.length
  end
  return text[0..endpoint]
end

STDOUT.sync = true

$posts = []

def firstImage(text)
  earliest_index = text.length
  match_data = false
  url = ""
  begin #find the first thing
    # imgur link, gets medium thumbnail (m)
    new_index = (text =~ /https?:\/\/.*?imgur\.com\/(\w*)/i)
    if new_index and new_index < earliest_index then
      earliest_index = new_index
      match_data = $~
      id = $~[1]
      url = "http://i.imgur.com/#{id}m.jpg"
    end
    # gfycat
    new_index = (text =~ /https?:\/\/.*?gfycat\.com\/(\w*)/i)
    if new_index and new_index < earliest_index then
      earliest_index = new_index
      match_data = $~
      # http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-thumb100.jpg
      # http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-poster.jpg
      url = "http://thumbs.gfycat.com/#{$~[1]}-poster.jpg"
    end
    # imgur albums
    new_index = (text =~ /https?:\/\/.*?imgur\.com\/a\/(\w*)/i)
    if new_index and new_index < earliest_index then
      earliest_index = new_index
      match_data = $~
      id = $~[1]
      album = $imgur.get_album(id)
      cover_id = album.cover
      url = "http://i.imgur.com/#{cover_id}.jpg"
    end
    # raw images
    new_index = (text =~ /(https?:\/\/.*?(?:png|jpg|jpeg|gif))/i)
    if new_index and new_index < earliest_index then
      earliest_index = new_index
      match_data = $~
      url =  $~[1]
    end
  end
  return url
end

def youtube(text)
  result = /https?:\/\/.*?youtube\.com\/watch\?v=([A-Za-z0-9_-]*)/i.match(text)
  if result then
    id = result[1]
    return "http://img.youtube.com/vi/#{id}/hqdefault.jpg"
  else
    return ''
  end
end

def twitter(text)
  
  result = /(https?:\/\/twitter\.com\/(\w+))/i.match(text)
  if result then
    return result[1], result[2]
  else
    return '',''
  end
end

def addPost(submission, comment)
  post = {}
  post[:firstline]  = limit_lines(comment.body, 1)
  post[:twolines]   = limit_lines(comment.body, 3)
  post[:firstimage] = firstImage(comment.body)
  post[:url] = "http://www.reddit.com/r/#{$gamedev.display_name}/comments/#{submission.id}//#{comment.id}"
  post[:twitter_link], post[:twitter_handle] = twitter(comment.body)
  post[:youtube] = youtube(comment.body)
  post[:created_utc] = comment.created_utc
  post[:created] = comment.created
  $posts.push(post)
end

submissions.each do |submission|
  print "#{'%-50s' % submission.title} - "
  $total = 0
  $top_level = 0
  $twitters = 0
  $images = 0
  $youtube = 0
  $got_feedback = 0
  def add_comments(submission, comment)
    if comment.is_a?(Redd::Object::Comment) then
      if $seen[comment.id] then return end
      $seen[comment.id] = true
      $total += 1
      print(".") if $total % 10 == 0
      if comment.parent_id == comment.link_id then
        $top_level += 1
        addPost(submission, comment)
      end
    elsif comment.is_a?(Redd::Object::MoreComments) then
      print ">"
      # comment.expand().things.each do |comment|
      #   add_comments(comment)
      # end
    else
    end
  end
  # expand(submission.comments)
  submission.comments({:limit => 19000, :depth => 1}).each do |comment|
    # puts "- #{comment.author} - #{limit_lines(comment.body)}"
    add_comments(submission, comment)
  end
  $perc2_total = $top_level
  puts "!"
  print "#{'%-50s' % submission.title} - "
  puts '%-20s' % "#{$total}/#{submission.num_comments} parsed - "
end


count = 0
missing = 0
twitter_count = 0
youtube_count = 0

puts $posts.length

$posts.each do |post|
  count += 1
  if post[:firstimage].length < 1 then
    missing += 1
  end
  twitter_count += 1 if post[:twitter_handle].length > 1
  youtube_count += 1 if post[:youtube].length > 1
  puts "#{post[:url]} #{post[:firstimage].length>1?'img':'   '} #{post[:youtube].length>1?'yt':'  '} #{post[:twitter_handle].length>1?'t':' '} #{post[:created_utc]}"
end

puts "images #{count-missing}/#{count} (#{perc(count-missing,count)})"
puts "twitter #{twitter_count}/#{count} (#{perc(twitter_count,count)})"
puts "youtube #{youtube_count}/#{count} (#{perc(youtube_count,count)})"


def dump_post(post)
  dump = "<a href='#{post[:url]}'><img src='#{post[:firstimage]}' width=100px></img></a>"

  return dump
end

$html = File.open( "output.html","w" )

$html << "<html><body>"

$posts.shuffle

$posts.each do |post|
  $html << dump_post(post)
end

$html << "</body></html>"

$html.close

STDOUT.flush