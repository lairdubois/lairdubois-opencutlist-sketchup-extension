module Ladb::OpenCutList

  require_relative '../../plugin'

  class CutlistLayoutToLayoutWorker

    def initialize(settings, cutlist)

      @part_ids = settings.fetch('part_ids', nil)
      @parts_colored = settings.fetch('parts_colored', false)

      @cutlist = cutlist

    end

    # -----

    def run

      layout_dir = File.join(Plugin.instance.temp_dir, 'layout')
      unless Dir.exist?(layout_dir)
        Dir.mkdir(layout_dir)
      end
      layout_file = File.join(layout_dir, 'ocl.layout')
      skp_file = File.join(layout_dir, 'ocl.skp')

      ####

      model = Sketchup.active_model

      definition = model.definitions.add('GLOP')

      points = []
      points << [0, 0, 0]
      points << [100, 0, 0]
      points << [100, 100, 0]
      points << [0, 100, 0]
      face = definition.entities.add_face(points)

      definition.save_as(skp_file)

      model.definitions.remove(definition)

      ###

      doc = Layout::Document.new
      page_info = doc.page_info
      pages = doc.pages
      page = pages.add("OpenCutList")

      bounds = Geom::Bounds2d.new(
        page_info.left_margin,
        page_info.top_margin,
        page_info.width - page_info.left_margin - page_info.right_margin,
        page_info.height - page_info.top_margin - page_info.bottom_margin
      )
      skp = Layout::SketchUpModel.new(skp_file, bounds)
      skp.perspective = false
      skp.view = Layout::SketchUpModel::TOP_VIEW
      skp.render_mode = Layout::SketchUpModel::VECTOR_RENDER
      skp.display_background = false
      doc.add_entity(skp, doc.layers.first, page)

      status = doc.save(layout_file)

    end

  end

end