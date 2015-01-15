
require 'sqlite3'



  # Quick hash utility from http://www.any-where.de/blog/ruby-hash-convert-string-keys-to-symbols/
  # putting it here is probably bad practice
  class Hash
    #take keys of hash and transform those to a symbols
    def self.transform_keys_to_symbols(value)
      return value if not value.is_a?(Hash)
      hash = value.inject({}){|memo,(k,v)| memo[k.to_sym] = Hash.transform_keys_to_symbols(v); memo}
      return hash
    end
  end

  # Quick hash utility from http://www.any-where.de/blog/ruby-hash-convert-string-keys-to-symbols/
  # putting it here is probably bad practice
  class Array
    #take keys of hash and transform those to a symbols
    def self.transform_keys_to_symbols(value)
      array = []
      value.each do |v|
        array << Hash.transform_keys_to_symbols(v);
      end
      return array
    end
  end

class SqliteCache < UrlFinder
  def initialize(db)
    # @db = SQLite3::Database.new(where)
    @db = db

    # Create a database
    rows = @db.execute <<-SQL
      create table IF NOT EXISTS image_cache (
        url text primary key,
        data blob
      );
    SQL

    @get = @db.prepare <<-SQL
      SELECT data FROM image_cache WHERE url = ?;
    SQL

    @put = @db.prepare <<-SQL
      INSERT OR REPLACE INTO image_cache (url, data) VALUES (?, ?)
    SQL
  end

  def handle(url)
    data = []
    continue = 2
    while continue > 0 do
      begin
        @get.execute(url) { |results|
          results.each do |row|
            data = JSON.parse(row[0].to_s)
            data = Array.transform_keys_to_symbols(data)
            puts "    RETRIEVING #{url} FROM CACHE"
          end
        }
        return data
      rescue Exception => e
        continue -= 1
        puts "///////////////////////////////////////////////////////////////// DB ERROR #{e.message}"
      end
    end
    return data
  end

  def store(url, results)
      puts "    CACHING #{url}"
    continue = 2
    while continue > 0 do
      begin
      @put.execute(url, SQLite3::Blob.new(results.to_json))
      return
      rescue Exception => e
        continue -= 1
        puts "///////////////////////////////////////////////////////////////// DB ERROR #{e.message}"
      end
    end
  end
end

