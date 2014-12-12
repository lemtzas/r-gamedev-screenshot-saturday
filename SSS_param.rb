# http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-thumb100.jpg
# http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-poster.jpg
# https://api.imgur.com/models/image
#   ex: http://i.imgur.com/cQzi1m.jpg
# http://miners.github.io/MinusAPIv2/v2/objects.html

$LOAD_PATH << '.'

require "rubygems"
require "bundler/setup"
require 'redd'
require 'imgur'
require 'SSS_web_helper.rb'
require 'SSS_webify.rb'
require 'filewatcher'
require 'optparse'
require 'yaml'



if File.exist?('conf.yaml') then
  options = YAML.load_file('conf.yaml')
else
  options = {}
end
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"
  opts.on('-s', '--subreddit SUBREDDIT', 'Subreddit to search (defautls to "gamedev")') { |v| options[:query] = v }
  opts.on('-q', '--query TEXT', 'Search Query; investigates first post (defautls to "flair:SSS")') { |v| options[:query] = v }
  opts.on('-p', '--id POST_ID', 'Post ID to investigate; overrides Query') { |v| options[:post_id] = v }
  opts.on('-o', '--output FILE', 'Output File name (defaults to index.html)') { |v| options[:output] = v }
  opts.on('-i', '--input LIQUID', 'Input Liquid Styling (defaults to index.liquid)') { |v| options[:input] = v }
  opts.on('-c', '--credentials USERNAME PASSWORD', 'Authentication Credentials for reddit (defaults to username/password keys in conf.yaml)') { |v,w| options[:username] = v; options[:password] = w }
  opts.on('-k', '--imgur_key KEY', 'Authentication key for imgur (defaults to imgur_key in conf.yaml)') { |v| options[:imgur_key] = v}
  opts.on('-w', '--watch', 'Watch for changes in liquid/webify') { options[:watch] = true }
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

options[:username] ||= "USERNAME HERE"
options[:password] ||= "PASSWORD HERE"
options[:useragent] ||= "/r/gamedev Parameterized Aggregator v0.1 by /u/lemtzas"
options[:subreddit] ||= "gamedev"
options[:query] ||= "flair:SSS"
options[:output] ||= "index.html"
options[:input] ||= "index.liquid"
options[:imgur_key] ||= "KEY HERE"

File.open("conf.yaml",'w') {|f| f.write(YAML.dump(options))}

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

if options[:username] != "USERNAME HERE" and options[:password] != "PASSWORD HERE" then
  $redd = Redd::Client::Authenticated.new_from_credentials(
        options[:username], options[:password],
        user_agent: options[:useragent])
else
  $redd = Redd::Client::Unauthenticated.new(user_agent: options[:useragent])
end

$imgur = Imgur.new(options[:imgur_key])

$subreddit = $redd.subreddit(options[:subreddit])
if options[:post_id] then
  options[:post_fullname] = "t3_#{options[:post_id]}"
  puts "getting results for #{options[:post_fullname]}"
  $submission = $redd.by_id(options[:post_fullname])[0]
  puts "submission title: #{$submission.title}"
else
  puts "checking first result for query: #{options[:query]}"

  submissions = $subreddit.search(options[:query],
               {:limit => 1,
                :restrict_sr => true,
                :sort => "new",
                :t => "all" })

  $submission = submissions[0]
end


results = SSSProcessor.process($submission)
# results[:images].each do |image|

# end
# results[:posts].each do |post|

# end

SSSDump.stat_dump(results[:posts])
SSSWebify.webify($submission, results[:posts], options[:output], options[:input])

if options[:watch] then
  puts "watching #{options[:input]} and SSS_webify.rb for changes"
  FileWatcher.new([options[:input],"SSS_webify.rb"]).watch do |filename|
    begin
      puts "updating site layout #{Time.now.to_s}"
      load "SSS_webify.rb"
      SSSWebify.webify($submission, results[:posts])
    rescue => e
      puts e
    end
  end
end

STDOUT.flush