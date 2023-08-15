module Ladb::OpenCutList

  require_relative '../../model/export/wrappers'

  class CutlistComputeLabelsFormulasWorker

    def initialize(settings, cutlist)

      @part_infos = settings.fetch('part_infos', nil)
      @layout = settings.fetch('layout', nil)

      @cutlist = cutlist

    end

    # -----

    def run
      return { :errors => [ 'default.error' ] } unless @cutlist
      return { :errors => [ 'tab.cutlist.error.obsolete_cutlist' ] } if @cutlist.obsolete?

      model = Sketchup.active_model
      return { :errors => [ 'tab.cutlist.error.no_model' ] } unless model

      @part_infos.each do |part_info|

        part_id = part_info['part']['id']
        part = @cutlist.get_real_parts([ part_id ]).first

        custom_values = []

        @layout.each do |element_def|

          if element_def['formula'] == 'custom'

            data = PartData.new(
              StringWrapper.new(part.number),
              StringWrapper.new(part.name),
              LengthWrapper.new(part.def.cutting_length),
              LengthWrapper.new(part.def.cutting_width),
              LengthWrapper.new(part.def.cutting_size.thickness),
              LengthWrapper.new(part.def.size.length),
              LengthWrapper.new(part.def.size.width),
              LengthWrapper.new(part.def.size.thickness),
              AreaWrapper.new(part.def.final_area),
              MaterialTypeWrapper.new(part.group.material_type),
              StringWrapper.new(part.group.material_display_name),
              StringWrapper.new(part.description),
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
            )
            custom_values.push(_evaluate_text(element_def['custom_formula'], data))

          else

            custom_values.push('')

          end

        end

        part_info['custom_values'] = custom_values

      end

      {
        :part_infos => @part_infos
      }
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

end

# -----

class PartData

  def initialize(
    number,
    name,
    cutting_length,
    cutting_width,
    cutting_thickness,
    bbox_length,
    bbox_width,
    bbox_thickness,
    final_area,
    material_type,
    material_name,
    description,
    tags,
    edge_ymin,
    edge_ymax,
    edge_xmin,
    edge_xmax,
    face_zmin,
    face_zmax,
    layer
  )
    @number =  number
    @name = name
    @cutting_length = cutting_length
    @cutting_width = cutting_width
    @cutting_thickness = cutting_thickness
    @bbox_length = bbox_length
    @bbox_width = bbox_width
    @bbox_thickness = bbox_thickness
    @final_area = final_area
    @material_type = material_type
    @material_name = material_name
    @description = description
    @tags = tags
    @edge_ymin = edge_ymin
    @edge_ymax = edge_ymax
    @edge_xmin = edge_xmin
    @edge_xmax = edge_xmax
    @face_zmin = face_zmin
    @face_zmax = face_zmax
    @layer = layer
  end

  def get_binding
    binding
  end

end
