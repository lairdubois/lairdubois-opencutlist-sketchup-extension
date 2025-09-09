module Ladb::OpenCutList

  require 'cgi'
  require_relative '../../lib/fiddle/imagy/imagy'

  class MaterialsLoadTextureWorker

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      response = {
          :texture_file => '',
      }

      # Ask for the load file path
      path = UI.openpanel(PLUGIN.get_i18n_string('tab.materials.texture_load.title'), '', "Image Files|*.jpg;*.jpeg;*.png;||")
      if path

        extname = File.extname(path).downcase
        return { :errors => [ 'tab.materials.error.invalid_image_file' ] } unless extname.match(/^\.(?:jpg|jpeg|png)$/)

        temp_dir = PLUGIN.temp_dir
        material_textures_dir = File.join(temp_dir, 'material_textures')
        if Dir.exist?(material_textures_dir)
          FileUtils.remove_dir(material_textures_dir, true)   # Temp dir exists we clean it
        end
        Dir.mkdir(material_textures_dir)

        texture_file = File.join(material_textures_dir, "#{SecureRandom.uuid}#{extname}")

        # Copy file to the temp folder
        FileUtils.cp(path, texture_file)

        # Load image
        if Fiddle::Imagy.load(texture_file)

          texture_image_width = Fiddle::Imagy.get_width
          texture_image_height = Fiddle::Imagy.get_height

          # Fetch image size in pixels
          response[:texture_ratio] = texture_image_width.to_f / texture_image_height
          response[:texture_image_width] = texture_image_width
          response[:texture_image_height] = texture_image_height

          response[:texture_file] = texture_file
          response[:texture_name] = File.basename(path, File.extname(path))

        else
          return { :errors => [ 'tab.materials.error.invalid_image_file' ] }
        end

      end

      response
    end

    # -----

  end

end