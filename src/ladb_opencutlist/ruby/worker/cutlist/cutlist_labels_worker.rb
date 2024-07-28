module Ladb::OpenCutList

  require_relative '../../model/labels/label_entry'
  require_relative '../../model/export/wrappers'
  require_relative '../../helper/part_drawing_helper'

  class CutlistLabelsWorker

    include PartDrawingHelper

    def initialize(cutlist,

                   part_ids: ,
                   layout: [],
                   part_order_strategy: '',

                   bin_defs: []

    )

      @cutlist = cutlist

      @part_ids = part_ids
      @layout = layout
      @part_order_strategy = part_order_strategy

      @bin_defs = bin_defs

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      # Retrieve parts
      parts = @cutlist.get_real_parts(@part_ids)
      return { :errors => [ 'tab.cutlist.error.no_part' ] } if parts.empty?

      entries = []

      # Loop on parts
      parts.each do |part|

        # Init position in batch
        position_in_batch = 0

        # Loop on instances
        part.def.instance_infos.each do |serialized_path, instance_info|

          # Init thickness layer
          thickness_layer = 0

          # Loop on thickness layers
          part.def.thickness_layer_count.times do

            thickness_layer += 1
            position_in_batch += 1
            bin = _shift_bin(part.id)

            # Create the label entry
            entry = LabelEntry.new(part)
            entry.entity_named_path = instance_info.named_path
            entry.entity_name = part.def.thickness_layer_count > 1 ? "#{instance_info.entity.name} // #{thickness_layer}" : instance_info.entity.name
            entry.thickness_layer = thickness_layer
            entry.position_in_batch = position_in_batch
            entry.bin = bin

            @layout.each do |element_def|

              if element_def['formula'].start_with?('custom')

                data = LabelData.new(

                  number: StringWrapper.new(part.number),
                  path: PathWrapper.new(instance_info.named_path.split('.')),
                  instance_name: StringWrapper.new(instance_info.entity.name),
                  name: StringWrapper.new(part.name),
                  cutting_length: LengthWrapper.new(part.def.cutting_length),
                  cutting_width: LengthWrapper.new(part.def.cutting_width),
                  cutting_thickness: LengthWrapper.new(part.def.cutting_size.thickness),
                  edge_cutting_length: LengthWrapper.new(part.def.edge_cutting_length),
                  edge_cutting_width: LengthWrapper.new(part.def.edge_cutting_width),
                  bbox_length: LengthWrapper.new(part.def.size.length),
                  bbox_width: LengthWrapper.new(part.def.size.width),
                  bbox_thickness: LengthWrapper.new(part.def.size.thickness),
                  final_area: AreaWrapper.new(part.def.final_area),
                  material: MaterialWrapper.new(part.group.def.material, part.group.def),
                  description: StringWrapper.new(part.description),
                  url: StringWrapper.new(part.url),
                  tags: ArrayWrapper.new(part.tags),
                  edge_ymin: EdgeWrapper.new(part.def.edge_materials[:ymin], part.def.edge_group_defs[:ymin]),
                  edge_ymax: EdgeWrapper.new(part.def.edge_materials[:ymax], part.def.edge_group_defs[:ymax]),
                  edge_xmin: EdgeWrapper.new(part.def.edge_materials[:xmin], part.def.edge_group_defs[:xmin]),
                  edge_xmax: EdgeWrapper.new(part.def.edge_materials[:xmax], part.def.edge_group_defs[:xmax]),
                  face_zmin: VeneerWrapper.new(part.def.veneer_materials[:zmin], part.def.veneer_group_defs[:zmin]),
                  face_zmax: VeneerWrapper.new(part.def.veneer_materials[:zmax], part.def.veneer_group_defs[:zmax]),
                  layer: StringWrapper.new(instance_info.layer.name),

                  component_definition: ComponentDefinitionWrapper.new(instance_info.definition),
                  component_instance: ComponentInstanceWrapper.new(instance_info.entity),

                  batch: BatchWrapper.new(position_in_batch, part.count),
                  bin: IntegerWrapper.new(bin),

                  filename: StringWrapper.new(@cutlist.filename),
                  model_name: StringWrapper.new(@cutlist.model_name),
                  model_description: StringWrapper.new(@cutlist.model_description),
                  page_name: StringWrapper.new(@cutlist.page_name),
                  page_description: StringWrapper.new(@cutlist.page_description)

                )
                entry.custom_values << _evaluate_text(element_def['custom_formula'], data)

              elsif element_def['formula'] == 'thumbnail.proportional.drawing'

                scale = 1 / [ part.def.size.length, part.def.size.width ].max
                transformation = Geom::Transformation.scaling(scale, -scale, 1.0)

                projection_def = _compute_part_projection_def(PART_DRAWING_TYPE_2D_TOP, part)
                if projection_def.is_a?(DrawingProjectionDef)
                  entry.custom_values << projection_def.layer_defs.map { |layer_def|
                    {
                      :depth => layer_def.depth,
                      :path => "#{layer_def.poly_defs.map { |poly_def| "M #{poly_def.points.map { |point| point.transform(transformation).to_a[0..1].map { |v| v.to_f.round(6) }.join(',') }.join(' L ')} Z" }.join(' ')}",
                    }
                  }
                end

              else

                entry.custom_values << ''

              end

            end

            entries << entry

          end

        end

      end

      { :entries => entries.sort { |entry_a, entry_b| LabelEntry::entry_order(entry_a, entry_b, @part_order_strategy) }.map!(&:to_hash) }
    end

    # -----

    private

    def _shift_bin(part_id)
      return nil unless @bin_defs.is_a?(Hash)
      bins = @bin_defs[part_id]
      return nil unless bins.is_a?(Array) && !bins.empty?
      bins.shift
    end

    def _evaluate_text(formula, data)
      begin
        text = eval(formula, data.get_binding)
        text = text.export if text.is_a?(Wrapper)
        text = text.to_s if !text.is_a?(String) && text.respond_to?(:to_s)
      rescue Exception => e
        text = { :error => e.message.split(/cutlist_labels_worker[.]rb:\d+:/).last } # Remove path in exception message
      end
      text
    end

  end

  # -----

  class LabelData

    def initialize(

      number:,
      path:,
      instance_name:,
      name:,
      cutting_length:,
      cutting_width:,
      cutting_thickness:,
      edge_cutting_length:,
      edge_cutting_width:,
      bbox_length:,
      bbox_width:,
      bbox_thickness:,
      final_area:,
      material:,
      description:,
      url:,
      tags:,
      edge_ymin:,
      edge_ymax:,
      edge_xmin:,
      edge_xmax:,
      face_zmin:,
      face_zmax:,
      layer:,

      component_definition:,
      component_instance:,

      batch:,
      bin:,

      filename:,
      model_name:,
      model_description:,
      page_name:,
      page_description:

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
      @material = material
      @material_type = material.type
      @material_name = material.name
      @material_description = material.description
      @material_url = material.url
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

      @component_definition = component_definition
      @component_instance = component_instance

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