require 'timeout'
require 'andand'
require 'uri'

class OGFinder < UrlFinder
  EXTENSION_CAPTURE = /([^.]*)$/i
  SCANNED_URLS = %w[dtd html xtm xhtml xht mht mhtml maff asp aspx adp bml cfm cgi ihtml jsp las lasso lassoapp pl php php? phtml rna r rnx shtml stm]

  def initialize(priority)
    @priority = priority
  end

  def handle(url)
    images = []
    uri = URI(url)
    extension = uri.path.andand.match(EXTENSION_CAPTURE).andand[1]
    return images unless (extension.empty? || SCANNED_URLS.include?(extension))
    begin
      # puts "\nopening #{site_url}"
      Timeout::timeout(30) {
        open( url,
              "User-Agent" => "Ruby/#{RUBY_VERSION}") {|f|

          contents = f.read
          # find the og:image data
          og_image_match = contents =~ /property="og:image" content="(.*?)"/i
          if og_image_match then
            data = {
              :priority => @priority,
              :url => $~[1].to_s,
              :source => url,
              :icon => "fa fa-binoculars",
              :rule => "opengraph"
            }
            images << data
          elsif contents =~ /property="twitter:image" content="(.*?)"/i
            data = {
              :priority => @priority,
              :url => $~[1].to_s,
              :source => url,
              :icon => "fa fa-binoculars",
              :rule => "twitter card"
            }
            images << data
          elsif contents =~ /rel="image_src" href="(.*?)"/i
            data = {
              :priority => @priority,
              :url => $~[1].to_s,
              :source => url,
              :icon => "fa fa-binoculars",
              :rule => "rel image_src"
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