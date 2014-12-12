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

$redd = Redd::Client::Unauthenticated.new(
      user_agent: "/r/gamedev SSS Aggregator v0.1 by /u/lemtzas")

$gamedev = $redd.subreddit("gamedev")

submissions = $gamedev.search("flair:SSS",
             {:limit => 1,
              :restrict_sr => true,
              :sort => "new",
              :t => "all" })

submissions.each do |submission|
  results = SSSProcessor.process(submission)
  # results[:images].each do |image|

  # end
  # results[:posts].each do |post|

  # end

  SSSDump.stat_dump(results[:posts])
  SSSWebify.webify(submission, results[:posts])

  FileWatcher.new(["index.liquid","SSS_webify.rb"]).watch do |filename|
    begin
      puts "updating site layout #{Time.now.to_s}"
      load "SSS_webify.rb"
      SSSWebify.webify(submission, results[:posts])
    rescue => e
      puts e
    end
  end
end

STDOUT.flush