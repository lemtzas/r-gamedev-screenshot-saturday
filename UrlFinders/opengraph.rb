require 'timeout'

# Allow open-uri to follow unsafe redirects (i.e. https to http).
# Relevant issue:
# http://redmine.ruby-lang.org/issues/3719
# Source here:
# https://github.com/ruby/ruby/blob/trunk/lib/open-uri.rb
module OpenURI
  class <<self
    alias_method :open_uri_original, :open_uri
    alias_method :redirectable_cautious?, :redirectable?
 
    def redirectable_baller? uri1, uri2
      valid = /\A(?:https?|ftp)\z/i
      valid =~ uri1.scheme.downcase && valid =~ uri2.scheme
    end
  end
 
  # The original open_uri takes *args but then doesn't do anything with them.
  # Assume we can only handle a hash.
  def self.open_uri name, options = {}
    value = options.delete :allow_unsafe_redirects
 
    if value
      class <<self
        remove_method :redirectable?
        alias_method :redirectable?, :redirectable_baller?
      end
    else
      class <<self
        remove_method :redirectable?
        alias_method :redirectable?, :redirectable_cautious?
      end
    end
 
    self.open_uri_original name, options
  end
end

class OGFinder < UrlFinder
  def initialize(priority)
    @priority = priority
  end

  def handle(url)
    images = []
    begin
      # puts "\nopening #{site_url}"
      Timeout::timeout(10) {
        open( url,
              "User-Agent" => "Ruby/#{RUBY_VERSION}") {|f|

          if f.content_type == 'text/html' then
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
          end
        }
      }
      
    rescue Exception => e
      $stderr.puts "OG MATCH FAILED #{url} #{e.message} \n#{e.backtrace.join("\n")}"
    end
    return images
  end
end