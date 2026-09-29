# Checks the JSON examples of guide.html against HardwareDescriptorDef, in
# plain ruby, outside SketchUp (tiny Length / DimensionUtils stubs).  ruby check.rb
ROOT = File.expand_path('../..', __dir__)
module Ladb; module OpenCutList; class DataContainer; end; end; end
class Numeric; def mm; self / 25.4; end; def to_l; to_f; end; end
class String
  def to_l
    m = strip.tr(',', '.').match(/\A(-?[\d.]+)\s*(mm|cm|m|")?\z/)
    raise ArgumentError, self if m.nil?
    m[1].to_f * { 'mm' => 1 / 25.4, 'cm' => 10 / 25.4, 'm' => 1000 / 25.4, '"' => 1.0, nil => 1 / 25.4 }[m[2]]
  end
end
module Ladb::OpenCutList
  module DimensionUtils
    def self.decimal_separator; '.'; end
    def self.str_to_ifloat(s, negative_allowed = false); s; end
  end
end
$LOADED_FEATURES << File.join(ROOT, 'src/ladb_opencutlist/ruby/utils/dimension_utils.rb')
require 'json'; require 'cgi'
require File.join(ROOT, 'src/ladb_opencutlist/ruby/model/hardware/hardware_descriptor_def.rb')
hd = Ladb::OpenCutList::HardwareDescriptorDef
html = File.read(File.join(ROOT, 'docs/hardware-guide/guide.html'))
pres = html.scan(%r{<pre>(.*?)</pre>}m).map { |(t)| CGI.unescapeHTML(t.gsub(/<[^>]+>/, '')) }
env = { 'format' => 'ocl-hardware', 'version' => 1, 'id' => 'x', 'name' => 'X' }
pres.each_with_index do |t, i|
  s = t.strip
  data = begin
    if s.start_with?('{') then JSON.parse(s)
    elsif s.start_with?('"a": {') then env.merge('type' => 'hinge', 'components' => JSON.parse("{#{s}}"))
    elsif s.start_with?('"variables"') then env.merge('type' => 'connector').merge(JSON.parse("{#{s}}"))
    elsif s.start_with?('"hardware"') || s.start_with?('"machining"') then env.merge('type' => 'connector', 'components' => { 'a' => JSON.parse("{#{s}}") })
    end
  rescue JSON::ParserError => e
    puts "##{i} JSON ERROR #{e.message[0, 80]}"; next
  end
  next if data.nil?
  d = hd.new(data)
  puts "##{i} #{s[0, 30].inspect} valid=#{d.valid?} #{d.errors.inspect}"
end
