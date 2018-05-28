module Ladb::OpenCutList

  require 'pathname'
  require 'securerandom'
  require_relative 'controller'
  require_relative '../model/material_attributes'

  class MaterialsController < Controller

    def initialize()
      super('materials')
    end

    def setup_commands()

      # Setup opencutlist dialog actions
      Plugin.register_command("materials_list") do ||
        list_command
      end
      Plugin.register_command("materials_purge_unused") do ||
        purge_unused_command
      end
      Plugin.register_command("materials_update") do |material_data|
        update_command(material_data)
      end
      Plugin.register_command("materials_remove") do |material_data|
        remove_command(material_data)
      end
      Plugin.register_command("materials_import_from_skm") do ||
        import_from_skm_command
      end
      Plugin.register_command("materials_export_to_skm") do |material_data|
        export_to_skm_command(material_data)
      end
      Plugin.register_command("materials_get_std_sizes") do |material_id|
        get_std_sizes_command(material_id)
      end

    end

    private

    # -- Commands --

    def list_command()

      model = Sketchup.active_model
      materials = model ? model.materials : []

      temp_dir = Plugin.temp_dir
      material_thumbnails_dir = File.join(temp_dir, 'material_thumbnails')
      if Dir.exist?(material_thumbnails_dir)
        FileUtils.remove_dir(material_thumbnails_dir, true)   # Temp dir exists we clean it
      end
      Dir.mkdir(material_thumbnails_dir)

      response = {
          :errors => [],
          :warnings => [],
          :filename => model ? Pathname.new(model.path).basename : '',
          :solidwood_material_count => 0,
          :sheetgood_material_count => 0,
          :bar_material_count => 0,
          :untyped_material_count => 0,
          :materials => []
      }
      materials.each { |material|

        thumbnail_file = File.join(material_thumbnails_dir, "#{SecureRandom.uuid}.png")
        material.write_thumbnail(thumbnail_file, 128)

        material_attributes = MaterialAttributes.new(material)

        response[:materials].push({
                                  :id => material.entityID,
                                  :name => material.name,
                                  :display_name => material.display_name,
                                  :thumbnail_file => thumbnail_file,
                                  :color => '#' + material.color.to_i.to_s(16),
                                  :attributes => {
                                      :type => material_attributes.type,
                                      :length_increase => material_attributes.length_increase,
                                      :width_increase => material_attributes.width_increase,
                                      :thickness_increase => material_attributes.thickness_increase,
                                      :std_thicknesses => material_attributes.std_thicknesses,
                                      :std_sections => material_attributes.std_sections,
                                      :std_sizes => material_attributes.std_sizes
                                  }
                              })

        case material_attributes.type
          when MaterialAttributes::TYPE_SOLID_WOOD
            response[:solidwood_material_count] += 1
          when MaterialAttributes::TYPE_SHEET_GOOD
            response[:sheetgood_material_count] += 1
          when MaterialAttributes::TYPE_BAR
            response[:bar_material_count] += 1
          else
            response[:untyped_material_count] += 1
        end
      }

      # Errors
      if model
        if materials.count == 0
          response[:errors].push('tab.materials.error.no_materials')
        end
      else
        response[:errors].push('tab.materials.error.no_model')
      end

      # Sort materials by type ASC, display_name ASC
      response[:materials].sort_by! { |v| [v[:display_name]] }

      response
    end

    def purge_unused_command()

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      materials = model.materials
      materials.purge_unused

    end

    def update_command(material_data)

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      name = material_data['name']
      display_name = material_data['display_name']
      attributes = material_data['attributes']
      type = MaterialAttributes.valid_type(attributes['type'])
      length_increase = attributes['length_increase']
      width_increase = attributes['width_increase']
      thickness_increase = attributes['thickness_increase']
      std_thicknesses = attributes['std_thicknesses']
      std_sections = attributes['std_sections']
      std_sizes = attributes['std_sizes']

      # Fetch material
      materials = model.materials
      material = materials[name]

      if material

        # Update properties
        if display_name != material.name
          material.name = display_name
        end

        # Update attributes
        material_attributes = MaterialAttributes.new(material)
        material_attributes.type = type
        material_attributes.length_increase = length_increase
        material_attributes.width_increase = width_increase
        material_attributes.thickness_increase = thickness_increase
        material_attributes.std_thicknesses = std_thicknesses
        material_attributes.std_sections = std_sections
        material_attributes.std_sizes = std_sizes
        material_attributes.write_to_attributes

      end

    end

    def remove_command(material_data)

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      name = material_data['name']

      response = {
          :errors => []
      }

      # Fetch material
      materials = model.materials
      material = materials[name]

      if material

        begin
          materials.remove(material)
        rescue
          response[:errors].push('tab.materials.error.failed_removing_material')
        end

      else
        response[:errors].push('tab.materials.error.failed_removing_material')
      end

      response
    end

    def import_from_skm_command

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      response = {
          :errors => []
      }

      # Fetch material
      materials = model.materials

      dir, filename = File.split(model.path)
      path = UI.openpanel(Plugin.get_i18n_string('tab.materials.import_from_skm.title'), dir, "Material Files|*.skm;||")
      if path

        begin
          materials.load(path)
        rescue
          response[:errors].push('tab.materials.error.failed_import_skm_file')
        end

      end

      response
    end

    def export_to_skm_command(material_data)

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      name = material_data['name']
      display_name = material_data['display_name']

      response = {
          :errors => [],
          :export_path => ''
      }

      # Fetch material
      materials = model.materials
      material = materials[name]

      if material

        dir, filename = File.split(model.path)
        path = UI.savepanel(Plugin.get_i18n_string('tab.materials.export_to_skm.title'), dir, display_name + '.skm')
        if path
          begin
            material.save_as(path)
            response[:export_path] = path
          rescue
            response[:errors].push('tab.materials.error.failed_export_skm_file')
          end
        end

      else
        response[:errors].push('tab.materials.error.failed_export_skm_file')
      end

      response
    end

    def get_std_sizes_command(material_data)

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      name = material_data['name']

      response = {
          :errors => [],
          :std_sizes => [],
      }

      # Fetch material
      materials = model.materials
      material = materials[name]

      if material

        material_attributes = MaterialAttributes.new(material)
        material_attributes.l_std_sizes.each { |std_size|
          response[:std_sizes].push({
                                        :length => std_size.length,
                                        :width => std_size.width,
                                    })
        }

      end

      response
    end

  end

end