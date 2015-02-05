require 'digest/md5'
require 'sqlite3'
require 'ImageProcessor'

$HTMLEntities = HTMLEntities.new()

class PageProcessor
  URL_REGEX = /(?<=\()https?:\/\/[^\s]+(?=\))|(?:https?:\/\/[^\s]+)/i
  def initialize(redd, db, imgur)
    @redd = redd
    @db = db
    @imgur = imgur

    # Create a database
    rows = @db.execute <<-SQL
      create table IF NOT EXISTS page_cache (
        page_fullname text primary key,
        url text,
        album_id text,
        album_deletehash text
      );
    SQL

    rows = @db.execute <<-SQL
      create table IF NOT EXISTS post_cache (
        post_fullname integer primary key,
        page_fullname integer,
        url text,
        hash text,
        FOREIGN KEY(page_fullname) REFERENCES page_cache(page_fullname)
      );
    SQL

    @get_page = @db.prepare <<-SQL
      SELECT * FROM page_cache WHERE page_fullname = ?;
    SQL

    @put_page = @db.prepare <<-SQL
      INSERT OR REPLACE INTO page_cache (page_fullname, url, album_id, album_deletehash) VALUES (?, ?, ?, ?)
    SQL

    @get_post = @db.prepare <<-SQL
      SELECT * FROM post_cache WHERE post_fullname = ?;
    SQL

    @put_post = @db.prepare <<-SQL
      INSERT OR REPLACE INTO post_cache (post_fullname, page_fullname, url, hash) VALUES (?, ?, ?, ?)
    SQL


    @image_processor = ImageProcessor.new(redd, db, imgur)


    @page_scanners = []
    @page_scanners << TwitterScanner.new()
    @page_scanners << TitleScanner.new()
    @page_scanners << CoverPicker.new()
    @page_scanners << TimeAfterScanner.new()
  end

  def process(submission)
    @album, @album_id, @album_deletehash = get_or_create_imgur_album(submission, submission.title, 'Screenshot Saturday aggregation')
    puts "#{@album.link} #{@album_id} #{@album_deletehash}"
    posts = get_all_top_level_comments(submission)
    liquid_data = {}
    packed_posts = []
    posts.each do |post|
      packed_posts << extract_post_data(submission,post)
    end


    @album.images = []
    packed_posts.each do |data|
      data[:images] = @image_processor.process(data)
      data[:images].each do |image|
        image[:thumbnail_id]
        @album.images << image[:thumbnail_id]
      end
      puts "-------------------------------------------------------------------------------"
      puts "REMAINING #{@imgur.remaining_in_hour} / #{@imgur.remaining_in_day}"
      puts "-------------------------------------------------------------------------------"
    end

    @page_scanners.each do |scanner|
      packed_posts.each do |data|
        scanner.scan(data, submission)
      end
    end

    
    @album.description = "Screenshot Saturday Aggregation - last updated #{Time.now.to_s}"
    @album.update(@imgur)

    # @album.images = []
    # packed_posts.each do |data|
    #   data[:images].each do |image|
    #     @album.images << image[:thumbnail_id]
    #   end
    # end
    # @album.description = "Screenshot Saturday Aggregation - last updated #{Time.now.to_s}"
    # @album.update(@imgur)
    packed_posts.sort! { |a,b| b[:created_utc].to_i <=> a[:created_utc].to_i }
    liquid_data[:posts] = packed_posts
    liquid_data[:fullname] = submission.fullname
    liquid_data[:now] = Time.now.to_s
    liquid_data[:submission_title] = submission.title
    liquid_data[:submission_url] = submission.url
    liquid_data[:last_time_after_text] = time_since(Time.at(submission.created), Time.now())
    liquid_data[:last_time_expiry] = ((Time.at(submission.created) + (60*60*24*7)) - Time.now()).to_i # expire 6 days after post,
    liquid_data[:album_url] = @album.link

    return liquid_data
  end

  private

  def extract_images_data(page_fullname, post_fullname, urls)
    return @image_processor.process(page_fullname, post_fullname, urls)
  end

  def get_or_create_imgur_album(submission, title, description)
    album = nil
    @get_page.execute(submission.fullname) { |resultset|
      resultset.each do |row|
        album = @imgur.get_album(row['album_id'].to_s)
        album.deletehash = row['album_deletehash']
      end
    }
    if not album then
      album = @imgur.new_album(nil, {:title=>title,:description=>description,:layout=>'grid'})
      @put_page.execute(submission.fullname, submission.url, album.id, album.deletehash)
    end
    return album, album.id, album.deletehash
  end

  def get_all_top_level_comments(submission)
    posts = [] #the result
    seen = {}  #post marking structure
    total = 0  #comment count
    print "#{'%-50s' % submission.title} - "
    submission.comments({:limit => 19000, :depth => 1}).each do |comment|
      # puts "- #{comment.author} - #{limit_lines(comment.body)}"
      if comment.is_a?(Redd::Object::Comment) then
        if seen[comment.id] then next end
        seen[comment.id] = true
        total += 1
        print(".") if $verbose and total % 10 == 0
        if comment.parent_id == comment.link_id then
          # post = process_post_2(submission, comment)
          posts.push(comment)
        end
      elsif comment.is_a?(Redd::Object::MoreComments) then
        print ">" if $verbose
        # comment.expand().things.each do |comment|
        #   add_comments(comment)
        # end
      end
    end
    puts "!" if $verbose
    print "#{'%-50s' % submission.title} - " if $verbose
    puts '%-20s' % "#{total}/#{submission.num_comments} read - " if $verbose
    return posts
  end

  def extract_post_data(submission,comment)
    data = {}
    data[:edited]         = comment.edited
    data[:fullname]       = comment.fullname
    data[:body_decoded]   = $HTMLEntities.decode(comment.body)
    data[:html]           = $HTMLEntities.decode(comment.body_html)
    data[:author]         = $HTMLEntities.decode(comment.author)
    data[:firstline]      = limit_lines(data[:body_decoded], 1)
    data[:twolines]       = limit_lines(data[:body_decoded], 3)
    data[:body]           = comment.body
    data[:url]            = "http://www.reddit.com/r/#{submission.subreddit_name}/comments/#{submission.id}//#{comment.id}"
    data[:created_utc]    = comment.created_utc
    data[:created]        = comment.created
    data[:urls]           = extract_urls(data[:body_decoded])
    data[:related]        = []
    return data
  end

  def limit_lines(text, max)
    endpoint = 0
    [1..max].each do
      endpoint = text.index("\n",endpoint+1) || text.length
    end
    return text[0..endpoint]
  end

  def extract_urls(text)
    # collect all the URLs
    urls = PQueue.new(){ |a,b|
      a.begin(0) > b.begin(0)
    }
    # urls = []
    text.scan(URL_REGEX) { |url|
      # puts "push '#{url.to_s}' #{$~.begin(0)}"

      urls << $~
    }
    return urls.to_a.collect{|a| a[0].to_s}
  end
end