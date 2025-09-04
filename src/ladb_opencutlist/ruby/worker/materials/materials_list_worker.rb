module Ladb::OpenCutList

  require_relative '../../utils/color_utils'

  class MaterialsListWorker

    def initialize(

                   material_order_strategy: 'name>type',

                   # Unused but present for preset compatibility
                   minimize_on_smart_paint: nil

    )

      @material_order_strategy = material_order_strategy

    end

    # -----

    def run

      model = Sketchup.active_model
      materials = model ? model.materials : nil

      temp_dir = PLUGIN.temp_dir
      material_thumbnails_dir = File.join(temp_dir, 'material_thumbnails')
      if Dir.exist?(material_thumbnails_dir)
        FileUtils.remove_dir(material_thumbnails_dir, true)   # Temp dir exists we clean it
      end
      Dir.mkdir(material_thumbnails_dir)

      response = {
          :errors => [],
          :warnings => [],
          :filename => model && !model.path.empty? ? File.basename(model.path) : PLUGIN.get_i18n_string('default.empty_filename'),
          :model_name => model ? model.name : '',
          :length_unit_strippedname => DimensionUtils.model_unit_is_metric ? DimensionUtils::UNIT_STRIPPEDNAME_METER : DimensionUtils::UNIT_STRIPPEDNAME_FEET,
          :mass_unit_strippedname => MassUtils.get_symbol,
          :currency_symbol => PriceUtils.currency_symbol,
          :solid_wood_material_count => 0,
          :sheet_good_material_count => 0,
          :dimensional_material_count => 0,
          :edge_material_count => 0,
          :hardware_material_count => 0,
          :untyped_material_count => 0,
          :materials => []
      }

      if materials
        materials.each { |material|

          thumbnail_file = File.join(material_thumbnails_dir, "#{SecureRandom.uuid}.png")
          size = material.texture.nil? ? 8 : [ 128, material.texture.image_width - 1, material.texture.image_height - 1 ].min
          material.write_thumbnail(thumbnail_file, size)

          material_attributes = MaterialAttributes.new(material)

          response[:materials].push(
              {
                  :id => material.entityID,
                  :name => material.name,
                  :display_name => material.display_name,
                  :thumbnail_file => thumbnail_file,
                  :color => ColorUtils.color_to_hex(material.color),
                  :alpha => material.alpha,
                  :colorized => material.materialType == Sketchup::Material::MATERIAL_COLORIZED_TEXTURED,
                  :textured => (material.materialType == Sketchup::Material::MATERIAL_TEXTURED || material.materialType == Sketchup::Material::MATERIAL_COLORIZED_TEXTURED),
                  :texture_rotation => 0,
                  :texture_file => nil,
                  :texture_width => material.texture.nil? ? nil : material.texture.width.to_l.to_s,
                  :texture_height => material.texture.nil? ? nil : material.texture.height.to_l.to_s,
                  :texture_ratio => material.texture.nil? ? nil : material.texture.width / material.texture.height,
                  :texture_image_width => material.texture.nil? ? nil : material.texture.image_width,
                  :texture_image_height => material.texture.nil? ? nil : material.texture.image_height,
                  :attributes => {
                      :type => material_attributes.type,
                      :description => material_attributes.description,
                      :url => material_attributes.url,
                      :thickness => material_attributes.thickness,
                      :length_increase => material_attributes.length_increase,
                      :width_increase => material_attributes.width_increase,
                      :thickness_increase => material_attributes.thickness_increase,
                      :std_lengths => material_attributes.std_lengths,
                      :std_widths => material_attributes.std_widths,
                      :std_thicknesses => material_attributes.std_thicknesses,
                      :std_sections => material_attributes.std_sections,
                      :std_sizes => material_attributes.std_sizes,
                      :grained => material_attributes.grained,
                      :edge_decremented => material_attributes.edge_decremented,
                      :raw_estimated => material_attributes.raw_estimated,
                      :multiplier_coefficient => material_attributes.multiplier_coefficient,
                      :std_volumic_masses => material_attributes.std_volumic_masses,
                      :std_prices => material_attributes.std_prices,
                      :std_cut_prices => material_attributes.std_cut_prices,
                  }
              }
          )

          case material_attributes.type
            when MaterialAttributes::TYPE_SOLID_WOOD
              response[:solid_wood_material_count] += 1
            when MaterialAttributes::TYPE_SHEET_GOOD
              response[:sheet_good_material_count] += 1
            when MaterialAttributes::TYPE_DIMENSIONAL
              response[:dimensional_material_count] += 1
            when MaterialAttributes::TYPE_EDGE
              response[:edge_material_count] += 1
            when MaterialAttributes::TYPE_HARDWARE
              response[:hardware_material_count] += 1
            else
              response[:untyped_material_count] += 1
          end
        }
      end

      # Errors
      if model
        if materials.count == 0
          response[:errors] << 'tab.materials.error.no_materials'
        end
      else
        response[:errors] << 'tab.materials.error.no_model'
      end

      # ShowTypeSeparator
      response[:show_type_separators] = [
        response[:solid_wood_material_count],
        response[:sheet_good_material_count],
        response[:dimensional_material_count],
        response[:edge_material_count],
        response[:hardware_material_count],
        response[:untyped_material_count]
      ].select { |v| v > 0 }.length > 1

      # Sort materials
      response[:materials].sort! { |material_a, material_b| MaterialAttributes::material_order(material_a, material_b, @material_order_strategy) }

      response
    end

    # -----

  end

end