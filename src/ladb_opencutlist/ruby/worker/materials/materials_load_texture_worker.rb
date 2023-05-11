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

        extname = File.extname(path).downcase
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

        # Load image
        image_rep = Sketchup::ImageRep.new
        begin
          image_rep.load_file(texture_file)
        rescue ArgumentError => e
          return { :errors => [ 'tab.materials.error.invalid_image_file' ] }
        end

        # Fetch image size in pixels
        response[:texture_ratio] = image_rep.width.to_f / image_rep.height
        response[:texture_image_width] = image_rep.width
        response[:texture_image_height] = image_rep.height

        response[:texture_file] = texture_file
      end

      response
    end

    # -----

  end

end