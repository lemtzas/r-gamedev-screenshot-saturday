require 'redd'
require 'imgur'
require 'kramdown'
require 'open-uri'
require 'htmlentities'
require 'liquid'
require 'liquidFilters.rb'
require 'UrlFinders/UrlFinder.rb'
require 'pqueue'
require 'rmagick'

$HTMLEntities = HTMLEntities.new()

class SSSProcessor
  def initialize()
    # $cache = UrlCache
    require 'UrlFinders/sqlite-cache.rb'
    puts "cache"
    $cache = SqliteCache.new("SSS_cache.sqlite")
    puts "cache2"

    # $url_finders = []
    # require 'UrlFinders/imgur.rb'
    # $url_finders.push(ImgurFinder.new(1))
  end

  def process(submission, verbose = true)
    images = []
    posts = []

    print "#{'%-50s' % submission.title} - "
    total = 0

    seen = {}
    expanded = {}

    # expand(submission.comments)
    submission.comments({:limit => 19000, :depth => 1}).each do |comment|
      # puts "- #{comment.author} - #{limit_lines(comment.body)}"
      if comment.is_a?(Redd::Object::Comment) then
        if seen[comment.id] then next end
        seen[comment.id] = true
        total += 1
        print(".") if verbose and total % 10 == 0
        if comment.parent_id == comment.link_id then
          post, image_list = process_post_2(submission, comment)
          posts.push(post)
          image_list.each do |image|
            images.push(image)
          end
        end
      elsif comment.is_a?(Redd::Object::MoreComments) then
        print ">" if verbose
        # comment.expand().things.each do |comment|
        #   add_comments(comment)
        # end
      end
    end
    puts "!" if verbose
    print "#{'%-50s' % submission.title} - " if verbose
    puts '%-20s' % "#{total}/#{submission.num_comments} parsed - " if verbose

    return {:posts=>posts, :images=>images}
  end

  ## helpers
  private

  $seen = {}

  $expanded = {}

  def expand(thing)
    was_expanded = true
    while was_expanded == true do
      was_expanded = false
      thing.each do |subthing|
        if subthing.is_a?(Redd::Object::MoreComments) and not $expanded[subthing] then
          subthing.expand()
          $expanded[subthing] = true
          print("'")
          was_expanded = true
        end
      end
    end
  end

  def limit_lines(text, max)
    endpoint = 0
    [1..max].each do
      endpoint = text.index("\n",endpoint+1) || text.length
    end
    return text[0..endpoint]
  end

  STDOUT.sync = true

  def firstImage(text)
    earliest_index = text.length
    match_data = false
    url = ""
    source = ""
    icon = ""
    rule = "no match"
    begin #find the first thing
      # imgur albums
      new_index = (text =~ /https?:\/\/[^\s]*?imgur\.com\/a\/(\w+)/i)
      if new_index and new_index < earliest_index then
        begin
          earliest_index = new_index
          match_data = $~
          id = $~[1]
          album = $imgur.get_album(id)
          cover_id = album.cover
          url = "http://i.imgur.com/#{cover_id}.jpg"
          source = $~.to_s
          icon = "fa fa-folder-open"
          rule = "imgur /a/"
        rescue NoMethodError, Exception => e #Imgur::NotFoundException, Imgur::UpdateException => e
          puts "imgur album #{$~.to_s} #{$~[1].to_s} failed"
        end
      end
      # imgur link, gets medium thumbnail (m)
      new_index = (text =~ /https?:\/\/[^\s]*?imgur\.com\/(?!gallery)([A-Za-z0-9_-]+)/i)
      if new_index and new_index < earliest_index then
        begin
          earliest_index = new_index
          match_data = $~
          id = $~[1]
          image = $imgur.get_image(id)
          url = "http://i.imgur.com/#{id}m.jpg"
          source = $~.to_s
          if image.animated then
            icon = "fa fa-spinner"
          else
            icon = ""
          end
          rule = "imgur"
        rescue NoMethodError, Exception => e #Imgur::NotFoundException, Imgur::UpdateException => e
          puts "imgur rule image #{$~.to_s} #{$~[1].to_s} failed"
        end
      end
      # imgur gallery link
      new_index = (text =~ /https?:\/\/[^\s]*?imgur\.com\/gallery\/([A-Za-z0-9_-]+)/i)
      if new_index and new_index < earliest_index then
        begin #try as album
          earliest_index = new_index
          match_data = $~
          id = $~[1]
          puts $~.to_s
          album = $imgur.get_album(id)
          cover_id = album.cover
          url = "http://i.imgur.com/#{cover_id}.jpg"
          source = $~.to_s
          icon = "fa fa-folder-open"
          rule = "imgur /gallery/ (album)"
        rescue Imgur::NotFoundException, Imgur::UpdateException => e
          begin #try as image
            earliest_index = new_index
            match_data = $~
            id = $~[1]
            image = $imgur.get_image(id)
            url = "http://i.imgur.com/#{id}m.jpg"
            source = $~.to_s
            if image.animated then
              icon = "fa fa-spinner"
            else
              icon = ""
            end
            rule = "imgur /gallery/ (image)"
          rescue Imgur::NotFoundException, Imgur::UpdateException => e
            puts $~.to_s
            raise e
          end
        end
      end
      # gfycat
      new_index = (text =~ /https?:\/\/[^\s]*?gfycat\.com\/(\w+)/i)
      if new_index and new_index < earliest_index then
        begin
          earliest_index = new_index
          match_data = $~
          # http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-thumb100.jpg
          # http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-poster.jpg
          url = "http://thumbs.gfycat.com/#{$~[1]}-poster.jpg"
          source = $~.to_s
          icon = "fa fa-spinner"
          rule = "gfycat"
        rescue => e
        end
      end
      # raw images
      new_index = (text =~ /(https?:\/\/[^\s]+?\.(png|jpg|jpeg|gif))/i)
      if new_index and new_index < earliest_index then
        begin
          earliest_index = new_index
          match_data = $~
          url =  $~[1]
          source = $~.to_s
          if $~[2] == 'gif' then
            icon = "fa fa-spinner"
          else
            icon = ""
          end
          rule = "raw image"
        rescue => e
        end
      end
      # vine
      new_index = (text =~ /https?:\/\/[^\s]*?(?:vineapp\.com|vine\.co)\/v\/([A-Za-z0-9_-]+)/i)
      if new_index and new_index < earliest_index then
        begin
          # get the page
          site_url = $~.to_s
          puts "\nopening #{site_url}"
          open( site_url,
                "User-Agent" => "Ruby/#{RUBY_VERSION}",) {|f|
            contents = f.read
            # find the og:image data
            og_image_match = contents =~ /property="og:image" content="(.*?)"/
            if og_image_match then
              earliest_index = new_index
              match_data = $~
              url =  $~[1].to_s
              source = site_url
              icon = "fa fa-vine"
              rule = "vine"
            end
          }
          
        rescue => e
        end
      end
      # youtube
      new_index = (text =~ /https?:\/\/[^\s]*?(?:youtube\.com\/watch\?v=|youtu\.be\/)([A-Za-z0-9_-]+)/i)
      if new_index and new_index < earliest_index then
        earliest_index = new_index
        match_data = $~
        url =  "http://img.youtube.com/vi/#{$~[1]}/hqdefault.jpg"
        source = $~.to_s
        icon = "fa fa-youtube-play"
        rule = "youtube"
      end
    end
    return url, source, icon, '%-20s' % rule
  end

  def backupFirstImage(text)
    earliest_index = text.length
    match_data = false
    url = ""
    source = ""
    icon = ""
    rule = "no match"
      # recordit.co
      new_index = (text =~ /https?:\/\/[^\s]*?recordit\.co\/(\w+)/i)
      if new_index and new_index < earliest_index then
        earliest_index = new_index
        match_data = $~
        # http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-thumb100.jpg
        # http://thumbs.gfycat.com/ThinSarcasticFinnishspitz-poster.jpg
        url = "http://g.recordit.co/#{$~[1]}.gif"
        source = $~.to_s
        icon = "fa fa-spinner"
        rule = "recordit"
      end
      # indiedb
      new_index = (text =~ /https?:\/\/[^\s]*?indiedb\.com\/[^\s\(\)]*/i)
      if new_index and new_index < earliest_index then
        begin
          # get the page
          site_url = $~.to_s
          puts "\nopening #{site_url}"
          open( site_url,
                "User-Agent" => "Ruby/#{RUBY_VERSION}",) {|f|
            contents = f.read
            # find the og:image data
            og_image_match = contents =~ /property="og:image" content="(.*?)"/
            if og_image_match then
              earliest_index = new_index
              match_data = $~
              url =  $~[1].to_s
              source = site_url
              icon = "fa fa-bookmark"
              rule = "indiedb"
            end
          }
          
        rescue => e
        end
      end
      # ludumdare
      new_index = (text =~ /https?:\/\/[^\s]*?ludumdare\.com\/[^\s\(\)]*/i)
      if new_index and new_index < earliest_index then
        begin
          # get the page
          site_url = $~.to_s
          puts "\nopening #{site_url}"
          puts "ld"
          open( site_url,
                "User-Agent" => "Ruby/#{RUBY_VERSION}",) {|f|
            contents = f.read
            # find the og:image data
            og_image_match = contents =~ /name="twitter:image" content="(.*?)"/
            puts $~.to_s
            if og_image_match then
              puts "match"
              earliest_index = new_index
              match_data = $~
              url =  $~[1].to_s
              source = site_url
              icon = "fa fa-bookmark"
              rule = "ludumdare"
            end
          }
          
        rescue => e
        end
      end
    return url, source, icon, '%-20s' % rule
  end

  def youtube(text)
    result = /https?:\/\/[^\s]*?youtube\.com\/watch\?v=([A-Za-z0-9_-]*)/i.match(text)
    if result then
      id = result[1]
      return result.to_s
    else
      return ''
    end
  end

  def twitter(text, flair)
    possible_handles = Queue.new
    # account link only
    if text =~ /https?:\/\/twitter\.com\/(\w+(?=\/|\s|\)))(?!\/status)/i then
      possible_handles.push($~[1])
    end
    # any twitter link
    if text =~ /(https?:\/\/twitter\.com\/(\w+))/i then
      possible_handles.push($~[1])
    end
    # check flair for @twitterhandles
    if flair =~ /^@(\w+)/ then
      possible_handles.push($~[1])
    end

    if not possible_handles.empty? then
      priority_handle = possible_handles.pop
      return "http://twitter.com/#{priority_handle}", priority_handle
    else
      return '',''
    end
  end

  def process_post(submission, comment)
    # puts comment.
    # comment = $redd.by_id(comment.link_id)[0]
    post = {}
    comment_body_processed = $HTMLEntities.decode(comment.body)
    comment_author_processed = $HTMLEntities.decode(comment.author)
    post[:edited] = comment.edited
    post[:author]   = $HTMLEntities.decode(comment.author)
    post[:firstline]  = limit_lines(comment_body_processed, 1)
    post[:twolines]   = limit_lines(comment_body_processed, 3)
    post[:body]   = comment.body
    post[:url] = "http://www.reddit.com/r/#{submission.subreddit_name}/comments/#{submission.id}//#{comment.id}"

    #TODO: REPLACE IMAGE DETECTION WITH GET_IMAGES
    get_images(comment, post[:title], post[:url], "jCW7Pj36yt9r5Ev")
    begin
      post[:firstimage], post[:source], post[:icon], post[:firstimagerule] = firstImage(comment_body_processed)
      if post[:firstimage].length == 0 then
        post[:firstimage], post[:source], post[:icon], post[:firstimagerule] = backupFirstImage(comment_body_processed)
      end
    rescue Exception => e
      puts post[:url]
      raise e
    end
    post[:twitter_link], post[:twitter_handle] = twitter(comment_body_processed, $HTMLEntities.decode(comment.author_flair_text))
    post[:youtube] = youtube(comment_body_processed)
    post[:created_utc] = comment.created_utc
    post[:created] = comment.created
    if post[:source].length == 0 then
      post[:source] = post[:url]
    end

    return post, []
  end

  def process_post_2(submission, comment)
    post = {}
    #metadata transfer
    comment_body_processed = $HTMLEntities.decode(comment.body)
    comment_author_processed = $HTMLEntities.decode(comment.author)
    post[:edited] = comment.edited
    post[:author]   = $HTMLEntities.decode(comment.author)
    post[:firstline]  = limit_lines(comment_body_processed, 1)
    post[:twolines]   = limit_lines(comment_body_processed, 3)
    post[:body]   = comment.body
    post[:url] = "http://www.reddit.com/r/#{submission.subreddit_name}/comments/#{submission.id}//#{comment.id}"
    post[:created_utc] = comment.created_utc
    post[:created] = comment.created
    # if post[:source].length == 0 then
    #   post[:source] = post[:url]
    # end

    #begin processing
    post[:urls] = get_urls(comment)
    post[:twitter_link], post[:twitter_handle] = get_twitter(post[:urls], $HTMLEntities.decode(comment.author_flair_text))
    post[:youtube] = get_youtube(post[:urls])


    post[:images] = get_images(comment, post[:urls], post[:author], post[:url], "jCW7Pj36yt9r5Ev")

    return post, []
  end

  def get_twitter(urls,flair)
    possible_handles = Queue.new
    # account link only
    urls.each do |url|
      if url =~ /https?:\/\/twitter\.com\/(\w+(?=\/|\s|\)))(?!\/status)/i then
        possible_handles.push($~[1])
      end
    end
    # any twitter link
    urls.each do |url|
      if url =~ /(https?:\/\/twitter\.com\/(\w+))/i then
        possible_handles.push($~[1])
      end
    end
    # check flair for @twitterhandles
    if flair =~ /^@(\w+)/ then
      possible_handles.push($~[1])
    end

    if not possible_handles.empty? then
      priority_handle = possible_handles.pop
      return "http://twitter.com/#{priority_handle}", priority_handle
    else
      return '',''
    end
  end

  def get_youtube(urls)
    urls.each do |url|
      result = url.match(/https?:\/\/[^\s]*?youtube\.com\/watch\?v=([A-Za-z0-9_-]*)/i)
      if result then
        return result.to_s
      else
        return ''
      end
    end
  end

  def get_urls(comment)
    # collect all the URLs
    urls = []
    comment.body.scan(/(?<=\()https?:\/\/[^\s]+(?=\))|(?:https?:\/\/[^\s]+)/i) { |url|
      puts "push '#{url.to_s}'"
      urls.push(url.to_s)
    }
    return urls
  end

  def get_images(comment, all_urls, thumb_title, thumb_description, thumb_album)
    images = PQueue.new(){ |a,b| # sort by lowest number priority and then earliest position
      
      if a[:priority] == b[:priority] then
        return a[:position] < b[:position]
      else
        return a[:priority] < b[:priority]
      end
    }
    # copy for temporary work
    urls = Array.new(all_urls)

    # check cache for known results and cull them
    urls.delete_if { |url|
      results = $cache.handle(url)
      results.each do |result|
        # the position and priority is needed for sorting information, so copy/default them
        result[:position] = comment.body.index(url)
        result[:priority] = result[:priority] or 0
        images.push(result)
      end
      if not results.empty? then
        puts "kill '#{url.to_s}'"
        return true
      end
    }
    # pass remaining urls to each handler, cache results and add to list, remove if found
    $url_finders.each do |url_finder|
      puts "RUNNING #{url_finder.class.name.upcase}"
      urls.delete_if { |url|
        puts "pass '#{url.to_s}' to #{url_finder.class.name}"
        results = url_finder.handle(url)
        results.each do |result|
          puts "     - #{result[:url]}"
          # the position and priority is needed for sorting information, so copy/default them
          result[:thumbnail] = make_thumbnail(result[:url], thumb_title, thumb_description, thumb_album)
          result[:position] = comment.body.index(url)
          result[:priority] = result[:priority] or 0
          images.push(result)
        end
        if (not results.empty?) then
          $cache.store(url, results)
          return true
        else
          return false
        end
      }
    end
    # return a sorted array of images
    return images.to_a
  end

  def make_thumbnail(url, title, description, album_id)
    begin
      puts "   processing #{url}"

      img = Magick::ImageList.new(url).first
      img.resize_to_fill!(200,200)
      img.write "temp_thumb.png"

      uploaded_image = $imgur.upload(Imgur::LocalImage.new('temp_thumb.png', title: title, description: description, album: album_id ))

      File.delete("temp_thumb.png") if File.exist?("temp_thumb.png")

      return uploaded_image.link
    rescue => e
      return ""
    end
  end
end

module SSSDump
  def self.stat_dump(posts)
    count = 0
    missing = 0
    twitter_count = 0
    youtube_count = 0

    posts.each do |post|
      count += 1
      if post[:firstimage].length < 1 then
        missing += 1
      end
      twitter_count += 1 if post[:twitter_handle].length > 1
      youtube_count += 1 if post[:youtube].length > 1
      puts "#{post[:url]} #{post[:edited]} #{post[:firstimage].length>1?'img':'   '} #{post[:youtube].length>1?'yt':'  '} #{post[:twitter_handle].length>1?'t':' '} #{post[:firstimagerule]} #{post[:firstimage]}"
    end

    puts "images #{count-missing}/#{count} (#{perc(count-missing,count)})"
    puts "twitter #{twitter_count}/#{count} (#{perc(twitter_count,count)})"
    puts "youtube #{youtube_count}/#{count} (#{perc(youtube_count,count)})"
  end




  class << self
    private
    def perc(v1,v2)
      (v1*100.0/v2).floor.to_s + "%"
    end
  end
end