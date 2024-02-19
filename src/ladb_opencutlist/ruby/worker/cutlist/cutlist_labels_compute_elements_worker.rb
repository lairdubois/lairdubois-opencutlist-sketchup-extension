module Ladb::OpenCutList

  require_relative '../../helper/part_drawing_helper'
  require_relative '../../model/export/wrappers'

  class CutlistLabelsComputeElementsWorker

    include PartDrawingHelper

    def initialize(settings, cutlist)

      @part_infos = settings.fetch('part_infos', [])
      @layout = settings.fetch('layout', [])

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      @part_infos.each do |part_info|

        next if part_info['part'].nil? || part_info['part']['id'].nil?

        part = @cutlist.get_real_parts([ part_info['part']['id'] ]).first
        next if part.nil?

        custom_values = []

        @layout.each do |element_def|

          if element_def['formula'] == 'custom'

            data = LabelData.new(
              StringWrapper.new(part.number),
              PathWrapper.new(part_info['entity_named_path'].split('.')),
              StringWrapper.new(part_info['entity_name']),
              StringWrapper.new(part.name),
              LengthWrapper.new(part.def.cutting_length),
              LengthWrapper.new(part.def.cutting_width),
              LengthWrapper.new(part.def.cutting_size.thickness),
              LengthWrapper.new(part.def.edge_cutting_length),
              LengthWrapper.new(part.def.edge_cutting_width),
              LengthWrapper.new(part.def.size.length),
              LengthWrapper.new(part.def.size.width),
              LengthWrapper.new(part.def.size.thickness),
              AreaWrapper.new(part.def.final_area),
              MaterialTypeWrapper.new(part.group.material_type),
              StringWrapper.new(part.group.material_display_name),
              StringWrapper.new(part.group.material_description),
              StringWrapper.new(part.group.material_url),
              StringWrapper.new(part.description),
              StringWrapper.new(part.url),
              ArrayWrapper.new(part.tags),
              EdgeWrapper.new(
                part.edge_material_names[:ymin],
                part.edge_material_colors[:ymin],
                part.def.edge_group_defs[:ymin] ? part.def.edge_group_defs[:ymin].std_thickness : nil,
                part.def.edge_group_defs[:ymin] ? part.def.edge_group_defs[:ymin].std_width : nil
              ),
              EdgeWrapper.new(
                part.edge_material_names[:ymax],
                part.edge_material_colors[:ymax],
                part.def.edge_group_defs[:ymax] ? part.def.edge_group_defs[:ymax].std_thickness : nil,
                part.def.edge_group_defs[:ymax] ? part.def.edge_group_defs[:ymax].std_width : nil
              ),
              EdgeWrapper.new(
                part.edge_material_names[:xmin],
                part.edge_material_colors[:xmin],
                part.def.edge_group_defs[:xmin] ? part.def.edge_group_defs[:xmin].std_thickness : nil,
                part.def.edge_group_defs[:xmin] ? part.def.edge_group_defs[:xmin].std_width : nil
              ),
              EdgeWrapper.new(
                part.edge_material_names[:xmax],
                part.edge_material_colors[:xmax],
                part.def.edge_group_defs[:xmax] ? part.def.edge_group_defs[:xmax].std_thickness : nil,
                part.def.edge_group_defs[:xmax] ? part.def.edge_group_defs[:xmax].std_width : nil
              ),
              VeneerWrapper.new(
                part.face_material_names[:zmin],
                part.face_material_colors[:zmin],
                part.def.veneer_group_defs[:zmin] ? part.def.veneer_group_defs[:zmin].std_thickness : nil
              ),
              VeneerWrapper.new(
                part.face_material_names[:zmax],
                part.face_material_colors[:zmax],
                part.def.veneer_group_defs[:zmax] ? part.def.veneer_group_defs[:zmax].std_thickness : nil
              ),
              ArrayWrapper.new(part.def.instance_infos.values.map { |instance_info| instance_info.layer.name }.uniq),
              BatchWrapper.new(part_info['position_in_batch'], part.count),
              IntegerWrapper.new(part_info['bin']),
              StringWrapper.new(@cutlist.filename),
              StringWrapper.new(@cutlist.model_name),
              StringWrapper.new(@cutlist.model_description),
              StringWrapper.new(@cutlist.page_name),
              StringWrapper.new(@cutlist.page_description)
            )
            custom_values.push(_evaluate_text(element_def['custom_formula'], data))

          elsif element_def['formula'] == 'thumbnail.proportional.drawing'

            scale = 1 / [ part.def.size.length, part.def.size.width ].max
            transformation = Geom::Transformation.scaling(scale, -scale, 1.0)

            projection_def = _compute_part_projection_def(PART_DRAWING_TYPE_2D_TOP, part)
            if projection_def.is_a?(DrawingProjectionDef)
              custom_values.push(projection_def.layer_defs.map { |layer_def|
                {
                  :depth => layer_def.depth,
                  :path => "#{layer_def.poly_defs.map { |poly_def| "M #{poly_def.points.map { |point| point.transform(transformation).to_a[0..1].map { |v| v.to_f.round(6) }.join(',') }.join(' L ')} Z" }.join(' ')}",
                }
              })
            end

          else

            custom_values.push('')

          end

        end

        part_info['custom_values'] = custom_values

      end

      { :part_infos => @part_infos }
    end

    # -----

    def _evaluate_text(formula, data)
      begin
        text = eval(formula, data.get_binding)
        text = text.export if text.is_a?(Wrapper)
        text = text.to_s if !text.is_a?(String) && text.respond_to?(:to_s)
      rescue Exception => e
        text = { :error => e.message.split(/cutlist_compute_labels_formulas_worker[.]rb:\d+:/).last } # Remove path in exception message
      end
      text
    end


  end

  # -----

  class LabelData

    def initialize(

      number,
      path,
      instance_name,
      name,
      cutting_length,
      cutting_width,
      cutting_thickness,
      edge_cutting_length,
      edge_cutting_width,
      bbox_length,
      bbox_width,
      bbox_thickness,
      final_area,
      material_type,
      material_name,
      material_description,
      material_url,
      description,
      url,
      tags,
      edge_ymin,
      edge_ymax,
      edge_xmin,
      edge_xmax,
      face_zmin,
      face_zmax,
      layer,

      batch,
      bin,

      filename,
      model_name,
      model_description,
      page_name,
      page_description

    )
      @number =  number
      @path = path
      @instance_name = instance_name
      @name = name
      @cutting_length = cutting_length
      @cutting_width = cutting_width
      @cutting_thickness = cutting_thickness
      @edge_cutting_length = edge_cutting_length
      @edge_cutting_width = edge_cutting_width
      @bbox_length = bbox_length
      @bbox_width = bbox_width
      @bbox_thickness = bbox_thickness
      @final_area = final_area
      @material_type = material_type
      @material_name = material_name
      @material_description = material_description
      @material_url = material_url
      @description = description
      @url = url
      @tags = tags
      @edge_ymin = edge_ymin
      @edge_ymax = edge_ymax
      @edge_xmin = edge_xmin
      @edge_xmax = edge_xmax
      @face_zmin = face_zmin
      @face_zmax = face_zmax
      @layer = layer

      @batch = batch
      @bin = bin

      @filename = filename
      @model_name = model_name
      @model_description = model_description
      @page_name = page_name
      @page_description = page_description

    end

    def get_binding
      binding
    end

  end

end
