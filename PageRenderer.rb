require 'kramdown'
require 'open-uri'
require 'htmlentities'
require 'liquid'
require 'liquidFilters.rb'

$HTMLEntities = HTMLEntities.new()

class PageRenderer
  def initialize()
     
  end

  def render(liquid_data, template='index.liquid', to_where='index.html')
    begin
      liquid_data = prepare_liquid_variables(liquid_data)

      # load our template
      puts "Reading template from #{template}"
      File.open( template,"r" ) { |f|
        @template = Liquid::Template.parse(f.read)
      }

      puts "Reading explanation file."
      explanation_file = File.open("explanation.md", "rb")
      explanation_text = explanation_file.read
      explanation_file.close()
      html = Kramdown::Document.new(explanation_text).to_html
      liquid_data["explanation_html"] = html

      puts "Writing HTML output to #{to_where}"
      # write the output
      File.open( to_where,"w" ) { |html|
        html << @template.render(liquid_data)
      }
    rescue Exception => e
      puts "Rendering Liquid failed."
      puts e.message
      puts e.backtrace.join("\n")
    end
  end

  def prepare_liquid_variables(liquid_data)
    liquid_data = liquid_data.deep_stringify_keys
    # puts liquid_data['posts'][0].to_yaml
    liquid_data["posts"].select{|i| i["author"] and i["author"].include?("Dawnfall")}.each do |i|
      puts "--------------------------------------------------------------------------------------"
      puts "--------------------------------------------------------------------------------------"
      puts i.to_yaml
    end
    return liquid_data
  end
end