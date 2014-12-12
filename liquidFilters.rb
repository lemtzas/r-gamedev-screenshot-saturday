require 'htmlentities'
require 'kramdown'
require 'liquid'

module SSSLiquidFilters
  @HTMLEntities = HTMLEntities.new()
  def kramdown(input)
    # input = @HTMLEntities.decode(input)
    Kramdown::Document.new(input).to_html
  end
  def HTMLDecode(input)
    @HTMLEntities.decode(input)
  end
end


Liquid::Template.register_filter(SSSLiquidFilters)