module Ladb::OpenCutList

  require_relative '../../model/labels/label_entry'
  require_relative '../../model/export/export_data'
  require_relative '../../helper/part_drawing_helper'
  require_relative '../../worker/common/common_eval_formula_worker'

  class CutlistLabelsWorker

    include PartDrawingHelper

    def initialize(cutlist,

                   part_ids: ,
                   layout: [],
                   part_order_strategy: '',

                   bin_defs: [],

                   compute_first_instance_only: false

    )

      @cutlist = cutlist

      @part_ids = part_ids
      @layout = layout
      @part_order_strategy = part_order_strategy

      @bin_defs = bin_defs

      @compute_first_instance_only = compute_first_instance_only

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

        # Init thickness layer
        thickness_layer = 0

        # Loop on thickness layers
        part.def.thickness_layer_count.times do

          thickness_layer += 1

          # Init position in batch
          position_in_batch = 0

          if part.virtual

            # Use part count to loop on virtual instances
            part.def.count.times do

              position_in_batch += 1
              bin = _shift_bin(part.id)

              entries << _create_entry(part, thickness_layer, position_in_batch, bin)

              break if @compute_first_instance_only
            end

          else

            # Loop on real instances
            part.def.instance_infos.each do |serialized_path, instance_info|

              position_in_batch += 1
              bin = _shift_bin(part.id)

              entity_named_path = instance_info.named_path
              entity_name = instance_info.entity.name
              layer_name = instance_info.layer.name
              definition = instance_info.definition
              entity = instance_info.entity

              entries << _create_entry(part, thickness_layer, position_in_batch, bin, entity_named_path, entity_name, layer_name, definition, entity)

              break if @compute_first_instance_only
            end

          end

          break if @compute_first_instance_only
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
      CommonEvalFormulaWorker.new(formula: formula, data: data).run
    end

    def _create_entry(part, thickness_layer, position_in_batch, bin, entity_named_path = '', entity_name = '', layer_name = '', definition = nil, entity = nil)

      # Create the label entry
      entry = LabelEntry.new(part)
      entry.entity_named_path = entity_named_path
      entry.entity_name = part.def.thickness_layer_count > 1 ? "#{entity_name} // #{thickness_layer}" : entity_name
      entry.thickness_layer = thickness_layer
      entry.position_in_batch = position_in_batch
      entry.bin = bin

      @layout.each do |element_def|

        if element_def['formula'].start_with?('custom')

          data = LabelData.new(

            number: StringExportWrapper.new(part.number),
            path: PathExportWrapper.new(entity_named_path.split('.')),
            instance_name: StringExportWrapper.new(entity_name),
            name: StringExportWrapper.new(part.name),
            cutting_length: LengthExportWrapper.new(part.def.cutting_length),
            cutting_width: LengthExportWrapper.new(part.def.cutting_width),
            cutting_thickness: LengthExportWrapper.new(part.def.cutting_size.thickness),
            edge_cutting_length: LengthExportWrapper.new(part.def.edge_cutting_length),
            edge_cutting_width: LengthExportWrapper.new(part.def.edge_cutting_width),
            bbox_length: LengthExportWrapper.new(part.def.size.length),
            bbox_width: LengthExportWrapper.new(part.def.size.width),
            bbox_thickness: LengthExportWrapper.new(part.def.size.thickness),
            final_area: AreaExportWrapper.new(part.def.final_area),
            material: MaterialExportWrapper.new(part.group.def.material, part.group.def),
            description: StringExportWrapper.new(part.description),
            url: StringExportWrapper.new(part.url),
            tags: ArrayExportWrapper.new(part.tags),
            edge_ymin: EdgeExportWrapper.new(part.def.edge_materials[:ymin], part.def.edge_group_defs[:ymin]),
            edge_ymax: EdgeExportWrapper.new(part.def.edge_materials[:ymax], part.def.edge_group_defs[:ymax]),
            edge_xmin: EdgeExportWrapper.new(part.def.edge_materials[:xmin], part.def.edge_group_defs[:xmin]),
            edge_xmax: EdgeExportWrapper.new(part.def.edge_materials[:xmax], part.def.edge_group_defs[:xmax]),
            face_zmin: VeneerExportWrapper.new(part.def.veneer_materials[:zmin], part.def.veneer_group_defs[:zmin]),
            face_zmax: VeneerExportWrapper.new(part.def.veneer_materials[:zmax], part.def.veneer_group_defs[:zmax]),
            layer: StringExportWrapper.new(layer_name),

            component_definition: ComponentDefinitionExportWrapper.new(definition),
            component_instance: ComponentInstanceExportWrapper.new(entity),

            batch: BatchExportWrapper.new(position_in_batch, part.count),
            bin: IntegerExportWrapper.new(bin),

            filename: StringExportWrapper.new(@cutlist.filename),
            model_name: StringExportWrapper.new(@cutlist.model_name),
            model_description: StringExportWrapper.new(@cutlist.model_description),
            page_name: StringExportWrapper.new(@cutlist.page_name),
            page_description: StringExportWrapper.new(@cutlist.page_description)

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

      entry
    end

  end

  # -----

  class LabelData < ExportData

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

  end

end