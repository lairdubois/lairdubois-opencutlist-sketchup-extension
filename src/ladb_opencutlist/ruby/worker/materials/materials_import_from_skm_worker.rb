module Ladb::OpenCutList

  require 'securerandom'

  class MaterialsImportFromSkmWorker

    ATTRIBUTE_TYPE_INTEGER = '4'.freeze
    ATTRIBUTE_TYPE_FLOAT = '6'.freeze
    ATTRIBUTE_TYPE_BOOLEAN = '7'.freeze
    ATTRIBUTE_TYPE_STRING = '10'.freeze
    ATTRIBUTE_TYPE_ARRAY = '11'.freeze

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Fetch material
      materials = model.materials

      last_dir = PLUGIN.read_default(Plugin::SETTINGS_KEY_MATERIALS_LAST_DIR, nil)
      if last_dir && File.exist?(last_dir) && File.directory?(last_dir)
        dir = last_dir
      else

        # Try to use SU Materials dir
        materials_dir = Sketchup.find_support_file('Materials', '')
        if File.directory?(materials_dir)

          # Join with OpenCutList subdir and create it if it doesn't exist
          dir = File.join(materials_dir, 'OpenCutList')
          unless File.directory?(dir)
            FileUtils.mkdir_p(dir)
          end

        else
          dir = File.dirname(model.path)
        end

      end

      dir = dir.gsub(/ /, '%20') if PLUGIN.platform_is_mac?

      path = UI.openpanel(PLUGIN.get_i18n_string('tab.materials.import_from_skm.title'), dir, "Material Files|*.skm;||")
      if path

        # Save last dir
        PLUGIN.write_default(Plugin::SETTINGS_KEY_MATERIALS_LAST_DIR, File.dirname(path))

        if Sketchup.version_number > 1800000000 # RubyZip is not compatible with SU 18-

          require_relative '../../lib/rubyzip/zip'

          # Try to extract material data
          Zip::File.open(path, create: false) do |zipfile|

            require "rexml/document"

            xml = zipfile.read('document.xml')

            begin

              # Parse XML
              doc = REXML::Document.new(xml)

              # Extract material element
              material_elm = doc.elements['/materialDocument/mat:material']

              # Retrieve material name
              name = material_elm.attribute('name').value

              material_old = materials[name]
              unless material_old.nil?

                choice = UI.messagebox(PLUGIN.get_i18n_string('tab.materials.import_from_skm.ask_replace', { :name => name }), MB_YESNOCANCEL)
                if choice == IDYES || choice == IDNO

                  # Rename old material with temp name to free loaded name
                  material_old.name = materials.unique_name(SecureRandom.uuid)

                  begin

                    # Load material
                    material_loaded = materials.load(path)

                  rescue RuntimeError => e

                    # Restore old material name
                    material_old.name = name

                    return { :errors => [ [ 'tab.materials.error.failed_import_skm_file', { :error => e.message } ] ] }
                  end

                  case choice
                  when IDYES

                    # Replace the old material attributes and properties by loaded ones

                    # Delete old attributes
                    attribute_dictionary_names_old = []
                    material_old.attribute_dictionaries.each { |dictionary| attribute_dictionary_names_old << dictionary.name }
                    attribute_dictionary_names_old.each { |name| material_old.attribute_dictionaries.delete(name) }

                    # Copy loaded material attributes and properties
                    material_loaded.attribute_dictionaries.each { |dictionary| dictionary.each { |key, value| material_old.set_attribute(dictionary.name, key, value) } }
                    material_old.alpha = material_loaded.alpha
                    material_old.color = material_loaded.color
                    material_old.colorize_type = material_loaded.colorize_type
                    if !material_loaded.texture.nil? && material_loaded.texture.valid?
                      material_old.texture = material_loaded.texture.image_rep
                      material_old.texture.size = [ material_loaded.texture.width, material_loaded.texture.height ]
                    end

                    material = material_old

                  when IDNO

                    # Create a new material and copy loaded attributes and properties to bypass default SU behavior when importing again

                    # Create a new material
                    material_new = materials.add(materials.unique_name(name))

                    # Copy loaded material attributes and properties
                    material_loaded.attribute_dictionaries.each { |dictionary| dictionary.each { |key, value| material_new.set_attribute(dictionary.name, key, value) } }
                    material_new.alpha = material_loaded.alpha
                    material_new.color = material_loaded.color
                    material_new.colorize_type = material_loaded.colorize_type
                    if !material_loaded.texture.nil? && material_loaded.texture.valid?
                      material_new.texture = material_loaded.texture.image_rep
                      material_new.texture.size = [ material_loaded.texture.width, material_loaded.texture.height ]
                    end

                    material = material_new

                  end

                  # Delete loaded material
                  materials.remove(material_loaded)

                  # Restore old material name
                  material_old.name = name

                  return { :material_id => material.entityID }

                elsif choice == IDCANCEL

                  return { :cancelled => true }

                end

              end

            rescue REXML::ParseException => e
              # Error while parsing XML. Continue with the default behavior
              puts e.message
            end

          end

        end

        begin
          material = materials.load(path)
          return { :material_id => material.entityID }
        rescue RuntimeError => e
          return { :errors => [ [ 'tab.materials.error.failed_import_skm_file', { :error => e.message } ] ] }
        end
      end

      { :cancelled => true }
    end

  end

end