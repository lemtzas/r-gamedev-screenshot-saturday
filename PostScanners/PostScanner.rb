require 'util/AbstractInterface'

class PostScanner
  include AbstractInterface

  # Checks URL for usable info
  #
  # * *Args*    :
  #   - +data+ -> The data for the post. this will be modified
  # * *Raises* :
  #   - +AbstractInterface::InterfaceNotImplementedError+ -> if not implemented
  #
  def scan(data)
    UrlFinder.api_not_implemented(self)
  end
end