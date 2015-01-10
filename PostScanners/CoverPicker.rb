require 'sqlite3'

class CoverPicker < PostScanner
  def initialize()
    
  end

  def scan(data, submission)
    return if not data[:images]
    return if not data[:images][0]
    primary = data[:images][0]
    if primary[:thumbnail] then
      data[:cover_bg] = primary[:thumbnail]
      data[:cover_url] = primary[:source]
      data[:cover_icon] = primary[:icon]
    else
      data[:cover_bg] = primary[:url]
      data[:cover_url] = primary[:source]
      data[:cover_icon] = primary[:icon]
    end
  end
end

