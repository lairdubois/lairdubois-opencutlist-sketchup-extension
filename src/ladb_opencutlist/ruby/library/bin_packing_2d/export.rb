module BinPacking2D
  class Export
    
    def initialize(bins, unplaced_boxes, group)
      @bins = bins
      @unplaced_boxes = unplaced_boxes
      @group = group
    end

    def to_html(options = {})
      template_path = File.expand_path("../export.canvas.html.erb", __FILE__)
      template = File.read(template_path)
      binding = ExportBinding.new(@bins, @unplaced_boxes, @group, options)
      html = ERB.new(template).result(binding.get_binding)
      html
    end
    
  end
end
