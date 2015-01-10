require 'sqlite3'

class TimeAfterScanner < PostScanner
  def initialize()
    
  end

  def scan(data, submission)
    data[:time_after] = time_since(Time.at(submission.created), Time.at(data[:created_utc]))
  end
end

