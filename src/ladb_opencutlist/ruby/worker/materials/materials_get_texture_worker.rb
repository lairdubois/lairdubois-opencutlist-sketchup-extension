module Ladb::OpenCutList

  class MaterialsGetTextureWorker

    def initialize(material_data)
      @name = material_data['name']
      @colorized = material_data['colorized']
    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      response = {
          :texture_file => '',
          :texture_colorized => false
      }

      # Fetch material
      materials = model.materials
      material = materials[@name]

      if material

        temp_dir = Plugin.instance.temp_dir
        material_textures_dir = File.join(temp_dir, 'material_textures')
        if Dir.exist?(material_textures_dir)
          FileUtils.remove_dir(material_textures_dir, true)   # Temp dir exists we clean it
        end
        Dir.mkdir(material_textures_dir)

        texture_file = File.join(material_textures_dir, "#{SecureRandom.uuid}.png")

        if Sketchup.version_number >= 16000000

          material.texture.write(texture_file, @colorized)

          response[:texture_colorized] = @colorized

        else

          # Workaround to write texture to file from SU prior to 2016

          # Create a fake face
          model = Sketchup.active_model
          entities = model.active_entities
          group = entities.add_group
          pts = []
          pts[0] = [0, 0, 0]
          pts[1] = [1, 0, 0]
          pts[2] = [1, 1, 0]
          pts[3] = [0, 1, 0]
          face = group.entities.add_face(pts)
          face.material = material

          tw = Sketchup.create_texture_writer
          tw.load(face, true)
          tw.write(face, true, texture_file)

          # Erease the group
          group.erase!

          # This BC workaround force texture to be colorized
          response[:texture_colorized] = true

        end

        response[:texture_file] = texture_file
      end

      response
    end

    # -----

  end

end