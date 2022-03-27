module Ladb::OpenCutList

  require 'cgi'

  class MaterialsLoadTextureWorker

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      response = {
          :texture_file => '',
      }

      # Ask for open file path
      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.materials.texture_load.title'), '', "Image Files|*.jpg;*.jpeg;*.png;||")
      if path

        extname = File.extname(path)
        return { :errors => [ 'tab.materials.error.invalid_image_file' ] } unless extname.match(/^\.(?:jpg|jpeg|png)$/)

        temp_dir = Plugin.instance.temp_dir
        material_textures_dir = File.join(temp_dir, 'material_textures')
        if Dir.exist?(material_textures_dir)
          FileUtils.remove_dir(material_textures_dir, true)   # Temp dir exists we clean it
        end
        Dir.mkdir(material_textures_dir)

        texture_file = File.join(material_textures_dir, "#{SecureRandom.uuid}#{extname}")

        # Copy file to temp folder
        FileUtils.cp(path, texture_file)

        response[:texture_file] = texture_file
      end

      response
    end

    # -----

  end

end