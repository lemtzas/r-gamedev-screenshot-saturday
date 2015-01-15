class YoutubeFinder < UrlFinder
  def initialize(priority)
    @priority = priority
  end

  def handle(url)
    images = []
    if url =~ /https?:\/\/[^\s]*?(?:youtube\.com\/watch\?v=|youtu\.be\/)([A-Za-z0-9_-]+)/i then
      match_data = $~
      id = $~[1]
      data = {
        :priority => @priority,
        :url => "http://img.youtube.com/vi/#{$~[1]}/hqdefault.jpg",
        :source => $~.to_s,
        :icon => "fa fa-youtube-play",
        :rule => "youtube"
      }
      images << data
      # related << {:link => url, :class => 'youtube', :icon => 'fa fa-youtube-play'}
    end
    return images
  end
end