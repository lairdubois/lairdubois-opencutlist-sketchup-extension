module Ladb::OpenCutList

  class MaterialsGetTextureWorker

    def initialize(material_data)
      
      @name = material_data.fetch('name')

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      response = {
          :texture_file => ''
      }

      # Fetch material
      materials = model.materials
      material = materials[@name]

      if material && material.texture

        temp_dir = Plugin.instance.temp_dir
        material_textures_dir = File.join(temp_dir, 'material_textures')
        if Dir.exist?(material_textures_dir)
          FileUtils.remove_dir(material_textures_dir, true)   # Temp dir exists we clean it
        end
        Dir.mkdir(material_textures_dir)

        texture_file = File.join(material_textures_dir, "#{SecureRandom.uuid}.png")

        material.texture.write(texture_file)

        response[:texture_file] = texture_file

      end

      response
    end

    # -----

  end

end