class GfycatFinder < UrlFinder
  def initialize(priority)
    @priority = priority
  end

  def handle(url)
    images = []
    if url =~ /https?:\/\/[^\s]*?gfycat\.com\/(\w+)/i then
      match_data = $~
      id = $~[1]
      data = {
        :priority => @priority,
        :url => "http://thumbs.gfycat.com/#{$~[1]}-poster.jpg",
        :source => $~.to_s,
        :icon => "fa fa-spinner",
        :rule => "gfycat"
      }
      images << data
    end
    return images
  end
end