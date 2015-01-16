class VineFinder < UrlFinder
  def initialize(priority)
    @priority = priority
  end

  def handle(url)
    images = []
    if url =~ /https?:\/\/[^\s]*?(?:vineapp\.com|vine\.co)\/v\/([A-Za-z0-9_-]+)/i then
      begin
        # get the page
        site_url = $~.to_s
        # puts "\nopening #{site_url}"
        open( site_url,
              "User-Agent" => "Ruby/#{RUBY_VERSION}",) {|f|
          contents = f.read
          # find the og:image data
          og_image_match = contents =~ /property="og:image" content="(.*?)"/
          if og_image_match then
            data = {
              :priority => @priority,
              :url => $~[1].to_s,
              :source => $~.to_s,
              :icon => "fa fa-vine",
              :rule => "vine"
            }
            images << data
          end
        }
        
      rescue Exception => e
        stderr.puts "VINE MATCH FAILED #{url}"
      end
    end
    return images
  end
end