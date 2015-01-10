class ImgurFinder < UrlFinder
  def initialize(priority)
    @priority = priority
    @imgur = $imgur
  end

  def handle(url)
    images = []
    # imgur albums
    if url =~ /https?:\/\/[^\s]*?imgur\.com\/a\/(\w+)/i then
      begin
        earliest_index = new_index
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
        puts "imgur album #{$~.to_s} #{$~[1].to_s} failed"
      end
    end
    # imgur link, gets medium thumbnail (m)
    if url =~ /https?:\/\/[^\s]*?imgur\.com\/(?!gallery)([A-Za-z0-9_-]+)/i then
      begin
        earliest_index = new_index
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
          :rule => "imgur plain/gallery"
        }
        images << data
      rescue NoMethodError, Exception => e #Imgur::NotFoundException, Imgur::UpdateException => e
        puts "imgur rule image #{$~.to_s} #{$~[1].to_s} failed"
      end
    end
    # imgur gallery link
    if url =~ /https?:\/\/[^\s]*?imgur\.com\/gallery\/([A-Za-z0-9_-]+)/i then
      begin #try as album
        earliest_index = new_index
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
          earliest_index = new_index
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
          puts $~.to_s
          raise e
        end
      end
    end
    return images
  end

  def scan(post)
    images = []
    # imgur albums
    text = post.body
    text.scan(/https?:\/\/[^\s]*?imgur\.com\/a\/(\w+)/i) { |match|
      begin
        id = match[1]
        album = @imgur.get_album(id)
        cover_id = album.cover
        url = "http://i.imgur.com/#{cover_id}.jpg"
        data = {
          :priority => @priority,
          :url => "http://i.imgur.com/#{cover_id}.jpg",
          :source => match.to_s,
          :icon => "fa fa-folder-open",
          :rule => "imgur /a/"
        }
        images.push[data]
      rescue NoMethodError, Exception => e #Imgur::NotFoundException, Imgur::UpdateException => e
        puts "imgur album #{match.to_s} #{match[1].to_s} failed"
      end
    }

    return images

    # OLD
    
  end
end

# $url_finders << ImgurFinder.new(1)