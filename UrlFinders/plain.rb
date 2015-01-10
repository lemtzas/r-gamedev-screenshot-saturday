class PlainFinder < UrlFinder
  def initialize(priority)
    @priority = priority
    @imgur = $imgur
  end

  def handle(url)
    images = []
    # imgur albums
    # raw images
    url.scan(/(https?:\/\/[^\s]+?\.(png|jpg|jpeg|gif))/i) { |match|
      data = {
        :priority => @priority,
        :url => match[0],
        :source => url,
        :icon => "fa fa-folder-open"
      }
      if $~[2] == 'gif' then
        data[:icon] = "fa fa-spinner"
      else
        data[:icon] = ""
      end
      data[:rule] = "PlainFinder"


      images.push data
    }
    return images
  end
end

# $url_finders << PlainFinder.new(1)

# puts "PLAINFINDER LOADED"