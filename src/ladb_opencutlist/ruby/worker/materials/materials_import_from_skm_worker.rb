module Ladb::OpenCutList

  require 'json'

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

      last_dir = Plugin.instance.read_default(Plugin::SETTINGS_KEY_MATERIALS_LAST_DIR, nil)
      if last_dir && File.directory?(last_dir) && File.exist?(last_dir)
        dir = last_dir
      else

        # Try to use SU Materials dir
        materials_dir = Sketchup.find_support_file('Materials', '')
        if File.directory?(materials_dir)

          # Join with OpenCutList subdir and create it if it dosen't exist
          dir = File.join(materials_dir, 'OpenCutList')
          unless File.directory?(dir)
            FileUtils.mkdir_p(dir)
          end

        else
          dir = File.dirname(model.path)
        end

      end

      dir = dir.gsub(/ /, '%20') if Plugin.instance.platform_is_mac

      path = UI.openpanel(Plugin.instance.get_i18n_string('tab.materials.import_from_skm.title'), dir, "Material Files|*.skm;||")
      if path

        # Save last dir
        Plugin.instance.write_default(Plugin::SETTINGS_KEY_MATERIALS_LAST_DIR, File.dirname(path))

        # Zip::File.open(path, create: false) { |zipfile|
        #
        #   require "rexml/document"
        #
        #   xml = zipfile.read('document.xml')
        #
        #   begin
        #
        #     # Parse XML
        #     doc = REXML::Document.new(xml)
        #
        #     # Extract material element
        #     material_elm = doc.elements['/materialDocument/mat:material']
        #
        #     # Retrieve material name
        #     name = material_elm.attribute('name').value
        #     puts "MANE = #{name}"
        #
        #     # Extract all material attribute dictionaries
        #     attribute_dictionaries = {}
        #     material_elm.elements.each("n0:AttributeDictionaries/n0:AttributeDictionary") { |attribute_dictionary_elm|
        #
        #       # Create the attribute dictionary
        #       attribute_dictionary = {}
        #       attribute_dictionaries.store(
        #         attribute_dictionary_elm.attribute('name').value,
        #         attribute_dictionary
        #       )
        #
        #       # Extract all of its attributes
        #       attribute_dictionary_elm.elements.each("n0:Attribute") { |attribute_elm|
        #         attribute_dictionary.store(
        #           attribute_elm.attribute('key').value,
        #           _extract_element_value(attribute_elm)
        #         )
        #       }
        #
        #     }
        #
        #     pp attribute_dictionaries
        #
        #   rescue REXML::ParseException => error
        #     # Return nil if an exception is thrown
        #     puts error.message
        #   end
        #
        # }
        # end

        begin
          material = materials.load(path)
          return { :material_id => material.entityID }
        rescue => e
          return { :errors => [ [ 'tab.materials.error.failed_import_skm_file', { :error => e.message } ] ] }
        end
      end

      {
          :cancelled => true
      }
    end

    # -----

    private

    def _extract_element_value(elm)
      case elm.attribute('type').value
      when ATTRIBUTE_TYPE_INTEGER
        value = elm.text.to_i
      when ATTRIBUTE_TYPE_FLOAT
        value = elm.text.to_f
      when ATTRIBUTE_TYPE_BOOLEAN
        value = elm.text.to_s == '1'
      when ATTRIBUTE_TYPE_STRING
        value = elm.cdatas.first.to_s
      when ATTRIBUTE_TYPE_ARRAY
        value = []
        elm.elements.each('value') { |value_elm|
          value.push(_extract_element_value(value_elm))
        }
      else
        value = nil
      end
      value
    end

  end

end