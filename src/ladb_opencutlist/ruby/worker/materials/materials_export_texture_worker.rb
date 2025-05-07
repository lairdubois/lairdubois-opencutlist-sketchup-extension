module Ladb::OpenCutList

  require_relative '../../lib/fiddle/imagy/imagy'
  require_relative '../../helper/sanitizer_helper'

  class MaterialsExportTextureWorker

    include SanitizerHelper

    def initialize(

                  name:,
                  colorized: false

    )

      @name = name
      @colorized = colorized

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      material = model.materials[@name]
      return { :errors => [ 'tab.materials.error.material_not_found' ] } if material.nil?
      return { :errors => [ 'tab.materials.error.no_texture' ] } if material.texture.nil?

      # Ask for the writing file path
      path = UI.savepanel(PLUGIN.get_i18n_string('tab.materials.texture_export.title'), '', _sanitize_filename(@name) + '.jpg')
      if path

        extname = File.extname(path).downcase
        return { :errors => [ 'tab.materials.error.invalid_image_file' ] } unless extname.match(/^\.(?:jpg|jpeg|png)$/)

        if material.texture.write(path, @colorized)
          return {
            :export_path => path
          }
        end

      end

      {
        :cancelled => true
      }
    end

    # -----

  end

end