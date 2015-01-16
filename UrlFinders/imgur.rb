class ImgurFinder < UrlFinder
  def initialize(priority)
    @priority = priority
    @imgur = $imgur
  end

  def handle(url)
    images = []
    # imgur albums
    if url =~ /https?:\/\/[^\s]*?imgur\.com\/a\/(\w+)/i then
      #TODO: fix to match album links...
      begin
        match_data = $~
        id = $~[1]
        album = $imgur.get_album(id)
        cover_id = album.cover

        data = {
          :priority => @priority,
          :url => "http://i.imgur.com/#{cover_id}.jpg",
          :source => $~.to_s,
          :icon => "fa fa-folder-open",
          :rule => "imgur /a/"
        }
        images << data
      rescue NoMethodError, Exception => e #Imgur::NotFoundException, Imgur::UpdateException => e
        $stderr.puts e.message
        $stderr.puts "imgur album #{$~.to_s} #{$~[1].to_s} failed"
      end
    end
    # imgur link, gets medium thumbnail (m)
    if url =~ /https?:\/\/[^\s]*?imgur\.com\/(?!gallery|a\/)([A-Za-z0-9_-]+)/i then
      #TODO: fix to not match album links
      begin
        match_data = $~
        id = $~[1]
        image = $imgur.get_image(id)
        source = $~.to_s
        if image.animated then
          icon = "fa fa-spinner"
        else
          icon = ""
        end
        data = {
          :priority => @priority,
          :url => "http://i.imgur.com/#{id}m.jpg",
          :source => $~.to_s,
          :icon => icon,
          :rule => "imgur plain"
        }
        images << data
      rescue NoMethodError, Exception => e #Imgur::NotFoundException, Imgur::UpdateException => e
        $stderr.puts "imgur rule image #{$~.to_s} #{$~[1].to_s} failed"
      end
    end
    # imgur gallery link
    if url =~ /https?:\/\/[^\s]*?imgur\.com\/gallery\/([A-Za-z0-9_-]+)/i then
      begin #try as album
        match_data = $~
        id = $~[1]
        puts $~.to_s
        album = $imgur.get_album(id)
        cover_id = album.cover

        data = {
          :priority => @priority,
          :url => "http://i.imgur.com/#{cover_id}.jpg",
          :source => $~.to_s,
          :icon => "fa fa-folder-open",
          :rule => "imgur /gallery/ (album)"
        }
        images << data
      rescue Imgur::NotFoundException, Imgur::UpdateException => e
        begin #try as image
          match_data = $~
          id = $~[1]
          image = $imgur.get_image(id)
          if image.animated then
            icon = "fa fa-spinner"
          else
            icon = ""
          end
          data = {
            :priority => @priority,
            :url => "http://i.imgur.com/#{id}m.jpg",
            :source => $~.to_s,
            :icon => icon,
            :rule => "imgur /gallery/ (image)"
          }
        rescue Imgur::NotFoundException, Imgur::UpdateException => e
          $stderr.puts $~.to_s
          raise e
        end
      end
    end
    return images
  end
end

# $url_finders << ImgurFinder.new(1)