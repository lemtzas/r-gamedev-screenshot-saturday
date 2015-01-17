require 'timeout'

class OGFinder < UrlFinder
  def initialize(priority)
    @priority = priority
  end

  def handle(url)
    images = []
    begin
      # puts "\nopening #{site_url}"
      Timeout::timeout(30) {
        open( url,
              "User-Agent" => "Ruby/#{RUBY_VERSION}") {|f|

          contents = f.read
          # find the og:image data
          og_image_match = contents =~ /property="og:image" content="(.*?)"/
          if og_image_match then
            data = {
              :priority => @priority,
              :url => $~[1].to_s,
              :source => url,
              :icon => "fa fa-binoculars",
              :rule => "opengraph"
            }
            images << data
          elsif contents =~ /property="twitter:image" content="(.*?)"/
            data = {
              :priority => @priority,
              :url => $~[1].to_s,
              :source => url,
              :icon => "fa fa-binoculars",
              :rule => "twitter card"
            }
            images << data
          end
        }
      }
      
    rescue Exception => e
      $stderr.puts "OG MATCH FAILED #{url} #{e.message} \n#{e.backtrace.join("\n")}"
    end
    return images
  end
end