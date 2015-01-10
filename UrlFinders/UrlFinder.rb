require 'util/AbstractInterface'

class UrlFinder
  include AbstractInterface

  # Checks URL for usable info
  #
  # * *Args*    :
  #   - +url+ -> The url in question
  # * *Returns* :
  #   - +image data structure+ -> {
  #        :priority => @priority, # will default to 0, lower is better
  #        :url => "http://i.imgur.com/#{cover_id}.jpg",
  #        :source => match.to_s,
  #        :icon => "fa fa-folder-open",
  #        :rule => "imgur /a/"}
  # * *Raises* :
  #   - +AbstractInterface::InterfaceNotImplementedError+ -> if not implemented
  #
  def process(url)
    UrlFinder.api_not_implemented(self)
  end
end