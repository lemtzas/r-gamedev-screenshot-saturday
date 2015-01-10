require 'sqlite3'

class TitleScanner < PostScanner
  def initialize()
    
  end

  def scan(data, submission)
    # directive scan
    data[:body].scan(/\[.*?\]\(\/botdata\s*?(?:\"|\')(.*?)\:(.*?)(?:\"|\')\)/i) { |directive,value|
      if directive == 'title' then
        data[:title] = value
      end
    }

    #guess
    if not data[:title] and data[:firstline] =~ /\*\*(.{,40})\*\*/i then
      data[:title] = $~[1].to_s
    end
    if not data[:title] and data[:firstline] =~ /\#+\s*(.{,40})\n/i then
      data[:title] = $~[1].to_s
    end
  end
end

