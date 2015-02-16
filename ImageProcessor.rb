require 'digest/md5'
require 'sqlite3'
require 'UrlFinders/sqlite-cache.rb'
require 'UrlFinders/imgur.rb'
require 'UrlFinders/plain.rb'
require 'UrlFinders/gfycat.rb'
require 'UrlFinders/youtube.rb'
require 'UrlFinders/vine.rb'
require 'UrlFinders/opengraph.rb'

$HTMLEntities = HTMLEntities.new()

class ImageProcessor
  def initialize(redd, db, imgur)
    @redd = redd
    @db = db
    @imgur = imgur

    @cacheFinder = SqliteCache.new(db)



    # the order here is important, if an earlier one matches a url, the later ones won't be called for it.
    # lower priorities will be sorted after higher priorities
    @image_finders = []
    @image_finders << PlainFinder.new(0)
    @image_finders << ImgurFinder.new(0)
    @image_finders << GfycatFinder.new(0)
    @image_finders << YoutubeFinder.new(0)
    @image_finders << VineFinder.new(0)
    @image_finders << OGFinder.new(-10)
  end

  def process(packed_data)
    # sort by lowest number priority and then earliest position
    images = PQueue.new(){ |a,b| 
      begin
        if a[:priority] == b[:priority] then
          a[:position] > b[:position]
        else
          a[:priority] < b[:priority]
        end
      rescue Exception => e
        puts a.to_s, b.to_s
        raise e
      end
    }
    # find all the links
    url_augments = []
    begin
      # first add override directives
      packed_data[:body].scan(/\[.*?\]\(\/botdata\s*?(?:\"|\')(.*?)\:(.*?)(?:\"|\')\)/i) { |directive,value|
        if directive == 'thumb' then
          url_augments << {
            :index => -1,
            :url => value,
            :position => -1,
            :data => []
          }
          break
        end

      }
      # add all regular links
      position = 0
      packed_data[:urls].each_with_index do |url,index|
        url_augments << {
          :index => index,
          :url => url,
          :position => position,
          :data => []
        }
        position += 1
      end
    end
    # submission.fullname, data[:fullname], 

    # check cache for known results
    url_augments.each_with_index { |augment|
      results = @cacheFinder.handle(augment[:url])
      results.each do |result|
        # the position and priority is needed for sorting information, so copy/default them
        # result[:position] = position
            result[:index] = augment[:index]
        result[:priority] = result[:priority] or 10
        result[:position] = augment[:position]
        # images.push(result)
        augment[:data] << result
      end
      if not results.empty? then
        puts "loaded cache of '#{augment[:url].to_s}'"
      end
    }

    # pass remaining urls to each handler, cache results and add to list, remove if found
    @image_finders.each do |url_finder|
      puts "RUNNING #{url_finder.class.name.upcase}"
      # if url_finder.respond_to? :scan then
      #   url_finder.scan(packed_data[:body_decoded])
      # end
      url_augments.each { |augment|
        if not augment[:position] then
          url = augment[:url]
          puts "pass '#{url.to_s}' to #{url_finder.class.name}"
          results = url_finder.handle(url)
          results.each do |result|
            puts "     - #{result[:url]}"
            # the position and priority is needed for sorting information, so copy/default them
            result[:index] = augment[:index]
            result[:position] = augment[:position]
            result[:priority] = result[:priority] or 10
            result[:retrieval_time] = Time.now.utc
            augment[:data] << result
          end
          # do a quick cache of the results in case anything bad happens
          @cacheFinder.store(augment[:url], augment[:data]) if not augment[:data].empty?
        end
        # if not results.empty? then
        #   $cache.store(url, results)
        #   return true
        # else
        #   return false
        # end
      }
    end

    # cache failures as well
    url_augments.each { |augment| 
      if augment[:data].empty? then
        # do a quick cache of the results in case anything bad happens
        @cacheFinder.store(augment[:url], {:none => true})
      end
    }

    # process images into final array, grab thumbnails if we can, and cache results
    url_augments.each { |augment|
      augment[:data].each do |data|
        if not data[:thumbnail] and @imgur.remaining_in_hour.to_i > 200 then
          data[:thumbnail], data[:thumbnail_id] = make_thumbnail(data[:url], packed_data[:title], packed_data[:author] + ": " + packed_data[:url])
        end
        @cacheFinder.store(augment[:url], augment[:data]) if not augment[:data].empty?
        images << data
      end
    }

    return images.to_a
  end

  def make_thumbnail(url, title, description)
    begin
      puts "   processing #{url}"

      img = Magick::ImageList.new(url).first
      img.resize_to_fill!(200,200)
      img.write "temp_thumb.png"

      uploaded_image = $imgur.upload(Imgur::LocalImage.new('temp_thumb.png', title: title, description: description ))

      # File.delete("temp_thumb.png") if File.exist?("temp_thumb.png")

      puts "   thumbnail: #{uploaded_image.link}"

      return uploaded_image.link, uploaded_image.id
    rescue => e
      return nil, nil
    end
  end
end