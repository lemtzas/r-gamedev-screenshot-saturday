require 'sqlite3'

class IconConsolidator < PostScanner
  def initialize()
    
  end

  def scan(data, submission)
    # count the icon types, fallback to fa fa-image if no icon provided
    icons = {}
    data[:images].each do |image|
      if not image[:icon].empty? then
        icons[image[:icon]] = (icons[image[:icon]] or 0) + 1
      else
        icons["fa fa-image"] = (icons["fa fa-image"] or 0) + 1
      end
    end

    data[:icons] = icons.collect{|k,v| {"icon" => k, "count" => v} }
  end
end

