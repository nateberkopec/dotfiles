require "rexml/document"

class Dotfiles::IcePlist
  PARSERS = {
    "dict" => :parse_dict,
    "array" => :parse_array,
    "true" => :parse_true,
    "false" => :parse_false,
    "integer" => :parse_integer,
    "real" => :parse_real,
    "data" => :parse_data
  }.freeze

  def self.parse(xml)
    new.parse(REXML::Document.new(xml).root.elements[1])
  end

  def parse(element)
    send(PARSERS.fetch(element.name, :parse_string), element)
  end

  private

  def parse_dict(element)
    element.elements.to_a.each_slice(2).map { |key, value| [key.text, parse(value)] }.to_h
  end

  def parse_array(element)
    element.elements.map { |child| parse(child) }
  end

  def parse_true(_element)
    true
  end

  def parse_false(_element)
    false
  end

  def parse_integer(element)
    element.text.to_i
  end

  def parse_real(element)
    element.text.to_f
  end

  def parse_data(element)
    element.text.to_s.unpack1("m")
  end

  def parse_string(element)
    element.text.to_s
  end
end
