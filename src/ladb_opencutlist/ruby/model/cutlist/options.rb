module Ladb::OpenCutList

  class CutlistGeneratorOptions

    attr_reader :auto_orient, :smart_material, :dynamic_attributes_name, :part_number_with_letters, :part_number_sequence_by_group, :part_folding, :part_order_strategy, :hide_labels, :hide_final_areas, :labels_filter, :edge_material_names_filter

    def initialize(settings)
      @auto_orient = settings['auto_orient']
      @smart_material = settings['smart_material']
      @dynamic_attributes_name = settings['dynamic_attributes_name']
      @part_number_with_letters = settings['part_number_with_letters']
      @part_number_sequence_by_group = settings['part_number_sequence_by_group']
      @part_folding = settings['part_folding']
      @part_order_strategy = settings['part_order_strategy']
      @hide_labels = settings['hide_labels']
      @hide_final_areas = settings['hide_final_areas']
      @labels_filter = settings['labels_filter']
      @edge_material_names_filter = settings['edge_material_names_filter']
    end

  end

  class CutlistExporterOptions

    attr_reader :source, :col_sep, :encoding, :hide_entity_names, :hide_labels, :hide_cutting_dimensions, :hide_bbox_dimensions, :hide_untyped_material_dimensions, :hide_final_areas, :hide_edges, :hidden_group_ids

    def initialize(settings)
      @source = settings['source']
      @col_sep = settings['col_sep']
      @encoding = settings['encoding']
      @hide_entity_names = settings['hide_entity_names']
      @hide_labels = settings['hide_labels']
      @hide_cutting_dimensions = settings['hide_cutting_dimensions']
      @hide_bbox_dimensions = settings['hide_bbox_dimensions']
      @hide_untyped_material_dimensions = settings['hide_untyped_material_dimensions']
      @hide_final_areas = settings['hide_final_areas']
      @hide_edges = settings['hide_edges']
      @hidden_group_ids = settings['hidden_group_ids']
    end

  end

  class CutlistNumbersOptions

    attr_reader :group_id

    def initialize(settings)
      @group_id = settings['group_id']
    end

  end

  class CutlistHighlightPartsOptions

    def initialize(settings)
    end

  end

  class CutlistGetThumbnailOptions

    attr_reader :definition_id

    def initialize(part_data)
      @definition_id = part_data['definition_id']
    end

  end

  class CutlistPartUpdateOptions

    PartData = Struct.new(
        :definition_id,
        :name,
        :is_dynamic_attributes_name,
        :material_name,
        :cumulable,
        :orientation_locked_on_axis,
        :labels,
        :axes_order,
        :axes_origin_position,
        :edge_material_names,
        :edge_entity_ids,
        :entity_ids
    )

    attr_reader :parts_data

    def initialize(settings)
      @parts_data = []

      parts_data = settings['parts_data']
      parts_data.each { |part_data|
        @parts_data << PartData.new(
            part_data['definition_id'],
            part_data['name'],
            part_data['is_dynamic_attributes_name'],
            part_data['material_name'],
            DefinitionAttributes.valid_cumulable(part_data['cumulable']),
            part_data['orientation_locked_on_axis'],
            DefinitionAttributes.valid_labels(part_data['labels']),
            part_data['axes_order'],
            part_data['axes_origin_position'],
            part_data['edge_material_names'],
            part_data['edge_entity_ids'],
            part_data['entity_ids'],
        )
      }

    end

  end

  class CutlistCuttingDiagram2dOptions

    attr_reader :group_id, :std_sheet_length, :std_sheet_width, :scrap_sheet_sizes, :grained, :hide_part_list, :saw_kerf, :trimming, :presort, :stacking, :bbox_optimization

    def initialize(settings)
      @group_id = settings['group_id']
      @std_sheet_length = DimensionUtils.instance.str_to_ifloat(settings['std_sheet_length']).to_l.to_f
      @std_sheet_width = DimensionUtils.instance.str_to_ifloat(settings['std_sheet_width']).to_l.to_f
      @scrap_sheet_sizes = DimensionUtils.instance.dxd_to_ifloats(settings['scrap_sheet_sizes'])
      @grained = settings['grained']
      @hide_part_list = settings['hide_part_list']
      @saw_kerf = DimensionUtils.instance.str_to_ifloat(settings['saw_kerf']).to_l.to_f
      @trimming = DimensionUtils.instance.str_to_ifloat(settings['trimming']).to_l.to_f
      @presort = BinPacking2D::Packing2D.valid_presort(settings['presort'])
      @stacking = BinPacking2D::Packing2D.valid_stacking(settings['stacking'])
      @bbox_optimization = BinPacking2D::Packing2D.valid_bbox_optimization(settings['bbox_optimization'])
    end

  end

end