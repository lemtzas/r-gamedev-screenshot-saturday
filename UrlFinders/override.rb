class OverrideFinder < UrlFinder
  def initialize(priority)
    @priority = priority
    @imgur = $imgur
  end

  def handle(url)
    return []
  end

  def scan(body)
  end
end

# $url_finders << PlainFinder.new(1)

# puts "PLAINFINDER LOADED"