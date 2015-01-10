require 'sqlite3'

class TwitterScanner < PostScanner
  def initialize()
    
  end

  def scan(data, submission)
    possible_handles = Queue.new

    # account link only
    data[:urls].each do |url|
      if url =~ /https?:\/\/twitter\.com\/(\w+(?=\/|\s|\)))(?!\/status)/i then
        possible_handles << $~[1]
      end
    end

    # any twitter link
    data[:urls].each do |url|
      if url =~ /(https?:\/\/twitter\.com\/(\w+))/i then
        possible_handles << $~[1]
      end
    end
    
    # check flair for @twitterhandles
    if data[:flair] =~ /^@(\w+)/ then
      possible_handles.push($~[1])
    end

    if not possible_handles.empty? then
      priority_handle = possible_handles.pop
      data[:twitter_link]   = "http://twitter.com/#{priority_handle}"
      data[:twitter_handle] = priority_handle
      data[:related] << {:link => data[:twitter_link], :class => 'twitter', :icon => 'fa fa-twitter'}
    end
  end
end

