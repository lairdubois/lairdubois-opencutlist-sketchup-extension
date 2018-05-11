module BinPacking2D
  class Export
    
    def initialize(bins)
      @bins = bins
    end

    def to_html(options = {})
      template_path = File.expand_path("../export.canvas.html.erb", __FILE__)
      template = File.read(template_path)
      binding = ExportBinding.new(@bins, options[:zoom] || 1, options[:kerf] || 2)
      html = ERB.new(template).result(binding.get_binding)
      html
    end
  end
end
