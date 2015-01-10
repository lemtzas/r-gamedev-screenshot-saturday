# http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-thumb100.jpg
# http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-poster.jpg
# https://api.imgur.com/models/image
#   ex: http://i.imgur.com/cQzi1m.jpg
# http://miners.github.io/MinusAPIv2/v2/objects.html

$LOAD_PATH << '.'
$LOAD_PATH << File.expand_path(File.dirname(__FILE__))

require "rubygems"
require "bundler/setup"
require 'active_support'
require 'active_support/all' 
require 'redd'
require 'imgur'
require 'SSS_web_helper.rb'
require 'SSS_webify.rb'
require 'filewatcher'
require 'optparse'
require 'yaml'
require 'PageProcessor'
require 'PageRenderer'
require 'sqlite3'

require 'PostScanners/PostScanner'
require 'UrlFinders/UrlFinder'
Dir[File.dirname(__FILE__) + '/UrlFinders/*.rb'].each {|file| require file }
Dir[File.dirname(__FILE__) + '/PostScanners/*.rb'].each {|file| require file }


if File.exist?('conf.yaml') then
  $options = YAML.load_file('conf.yaml')

  $options[:username] ||= "USERNAME HERE"
  $options[:password] ||= "PASSWORD HERE"
  $options[:useragent] ||= "/r/gamedev Parameterized Aggregator v0.1 by /u/lemtzas"
  $options[:subreddit] ||= "gamedev"
  $options[:query] ||= "flair:SSS"
  $options[:output] ||= "index.html"
  $options[:input] ||= "index.liquid"
  $options[:imgur_key] ||= "KEY HERE"
  $options[:sqlite_location] ||= "cache.sqlite"

  File.open("conf.yaml",'w') {|f| f.write(YAML.dump($options))}
else
  $options = {}

  $options[:username] ||= "USERNAME HERE"
  $options[:password] ||= "PASSWORD HERE"
  $options[:useragent] ||= "/r/gamedev Parameterized Aggregator v0.1 by /u/lemtzas"
  $options[:subreddit] ||= "gamedev"
  $options[:query] ||= "flair:SSS"
  $options[:output] ||= "index.html"
  $options[:input] ||= "index.liquid"
  $options[:imgur_key] ||= "KEY HERE"
  $options[:sqlite_location] ||= "cache.sqlite"

  File.open("conf.yaml",'w') {|f| f.write(YAML.dump($options))}
end
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"
  opts.on('-s', '--subreddit SUBREDDIT', 'Subreddit to search (defautls to "gamedev")') { |v| $options[:query] = v }
  opts.on('-q', '--query TEXT', 'Search Query; investigates first post (defautls to "flair:SSS")') { |v| $options[:query] = v }
  opts.on('-p', '--id POST_ID', 'Post ID to investigate; overrides Query') { |v| $options[:post_id] = v }
  opts.on('-o', '--output FILE', 'Output File name (defaults to index.html)') { |v| $options[:output] = v }
  opts.on('-i', '--input LIQUID', 'Input Liquid Styling (defaults to index.liquid)') { |v| $options[:input] = v }
  opts.on('-c', '--credentials USERNAME PASSWORD', 'Authentication Credentials for reddit (defaults to username/password keys in conf.yaml)') { |v,w| $options[:username] = v; $options[:password] = w }
  opts.on('-k', '--imgur_key KEY', 'Authentication key for imgur (defaults to imgur_key in conf.yaml)') { |v| $options[:imgur_key] = v}
  opts.on('-w', '--watch', 'Watch for changes in liquid/webify') { $options[:watch] = true }
  opts.on('-f', '--false', 'False start; just do the prep.') { $HAMMERTIME = true }
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

#some quick addons
begin
  # Quick addition to allow searching a subreddit
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
      puts "searching /r/#{display_name}"
      client.object_from_response :get, "/r/#{display_name}/search.json", params
    end
  end
  Redd::Object::Subreddit.include(SubSearch)

  


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
    return time
  end
end

# create $redd client as authed or unauthed depending on if credentials were provided
if $options[:username] != "USERNAME HERE" and $options[:password] != "PASSWORD HERE" then
  $redd = Redd::Client::Authenticated.new_from_credentials(
        $options[:username], $options[:password],
        user_agent: $options[:useragent])
else
  $redd = Redd::Client::Unauthenticated.new(user_agent: $options[:useragent])
end

# set up imgur
$imgur = Imgur.new($options[:imgur_key])
credits = $imgur.credits()
puts "#{credits.to_s}"
puts "IMGUR CREDITS REMAINING: #{credits["UserRemaining"].to_s}"
puts "RESET DATE: #{Time.at(credits["UserReset"]).to_datetime.to_s}"

$db = SQLite3::Database.new($options[:sqlite_location])
$db.results_as_hash = true

# load the interpreters
$url_finders = []
$post_scanners = []

submission = nil

# find the submission
$subreddit = $redd.subreddit($options[:subreddit])
if $options[:post_id] then
  $options[:post_fullname] = "t3_#{$options[:post_id]}"
  puts "getting results for #{$options[:post_fullname]}"
  $submission = $redd.by_id($options[:post_fullname])[0]
  puts "submission title: #{$submission.title}"
else
  puts "checking first result for query: #{$options[:query]}"

  submissions = $subreddit.search($options[:query],
               {:limit => 1,
                :restrict_sr => true,
                :sort => "new",
                :t => "all" })

  submission = submissions[0]
end

$verbose = true

# process the submission
if submission then
  puts "found '#{submission.title}' by /u/#{submission.author}"

  if $HAMMERTIME then
    exit
  end
  pp = PageProcessor.new($redd, $db, $imgur)
  packed_data = pp.process(submission)

  PageRenderer.new().render(packed_data, $options[:input], $options[:output])

  if $options[:watch] then
    puts "watching #{$options[:input]} and PageRenderer.rb for changes"
    FileWatcher.new([$options[:input],"PageRenderer.rb"]).watch do |filename|
      begin
        puts "updating site layout #{Time.now.to_s}"
        load "PageRenderer.rb"
        PageRenderer.new().render(packed_data, $options[:input], $options[:output])
      rescue => e
        puts e
      end
    end
  end
end




# # process the submission
# processor = SSSProcessor.new()
# results = processor.process($submission)
# # results[:images].each do |image|

# # end
# # results[:posts].each do |post|

# # end

# # dump the results to .html
# SSSDump.stat_dump(results[:posts])
# SSSWebify.webify($submission, results[:posts], $options[:output], $options[:input])

# if $options[:watch] then
#   puts "watching #{$options[:input]} and SSS_webify.rb for changes"
#   FileWatcher.new([$options[:input],"SSS_webify.rb"]).watch do |filename|
#     begin
#       puts "updating site layout #{Time.now.to_s}"
#       load "SSS_webify.rb"
#       SSSWebify.webify($submission, results[:posts])
#     rescue => e
#       puts e
#     end
#   end
# end

# STDOUT.flush
