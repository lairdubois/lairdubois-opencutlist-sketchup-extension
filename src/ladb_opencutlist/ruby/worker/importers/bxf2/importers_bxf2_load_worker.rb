module Ladb::OpenCutList

  require_relative '../../../lib/rubybxf/bxf'
  require_relative '../../../helper/layer0_caching_helper'
  require_relative '../../../helper/material_attributes_caching_helper'
  require_relative '../../../utils/color_utils'

  class ImportersBxf2LoadWorker

    include Layer0CachingHelper
    include MaterialAttributesCachingHelper

    def initialize(

                   path: ,
                   filename:

    )

      @path = path
      @filename = filename

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.importers.default.error.no_model' ] } unless model

      response = {
          :errors => [],
          :warnings => [],
          :path => @path,
          :filename => @filename
      }

      response[:warnings] << 'tab.importers.bxf2.warning.partial_support' unless Sketchup.version_number >= 2110000000

      begin

        file_extname = File.extname(@path)

        bxf_model = nil

        if file_extname.downcase == '.zip'

          # Try to load from zip file
          # BXF2 file must have the same name as the zip file

          require_relative '../../../lib/rubyzip/zip'

          Zip::File.open(@path) do |zip_file|
            zip_file.each do |entry|

              # Finding first BXF2 file in zip archive
              if File.extname(entry.name).downcase == '.bxf2'
                entry.get_input_stream do |stream|
                  bxf_model = Bxf::BxfModel.load(stream.read)
                  bxf_model.path = @path
                end
                break
              end

            end
          end

        end
        if bxf_model.nil?
          bxf_model = Bxf::BxfModel.load_from_file_path(@path)
        end

        response[:model] = {
          :author => bxf_model.author,
          :date => bxf_model.date,
          :cabinets => _process_scene(bxf_model.scene, []),
          :articles => bxf_model.library.articles.map { |id, article| {
            :total_quantity => article.total_quantity,
            :article_number => article.article_number.to_s,
            :description => article.description.to_s,
            :material => article.material.to_s,
          } }.sort_by { |v| v[:description] },
        }

        response[:available_layers] = model.layers.select { |layer| layer != cached_layer0 }.map { |layer| {
          :name => layer.name,
          :path => if layer.respond_to?(:folder) && layer.folder
                     folders = []
                     folder = layer.folder
                     while folder
                       folders.unshift(folder.name)
                       folder = folder.folder
                     end
                     folders
                   else
                     []
                   end,
          :color => ColorUtils.color_to_hex(layer.color),
        } }

        response[:available_materials] = model.materials.map { |material| {
          :type => _get_material_attributes(material).type,
          :name => material.name,
          :color => ColorUtils.color_to_hex(material.color),
        } }

      rescue Exception => e
        PLUGIN.dump_exception(e)
        return { errors: [ [ 'tab.importers.bxf2.error.failed_to_load_bxf2_file', { :error => e.message } ] ] }
      end

      [ response, bxf_model ]
    end

    # -----

    def _process_scene(bxf_scene, cabinets)
      _process_nodes(bxf_scene.nodes, cabinets)
      cabinets
    end

    def _process_nodes(bxf_nodes, cabinets)
      bxf_nodes.each do |bxf_node|
        _process_node(bxf_node, cabinets)
      end
      cabinets
    end

    def _process_node(bxf_node, cabinets)
      _process_cabinet_group_links(bxf_node.cabinet_group_links, cabinets)
      _process_cabinet_links(bxf_node.cabinet_links, cabinets)
      _process_nodes(bxf_node.nodes, cabinets)
      cabinets
    end

    def _process_cabinet_group_links(bxf_cabinet_group_links, cabinets)
      bxf_cabinet_group_links.each do |bxf_cabinet_group_link|
        bxf_cabinet_group = bxf_cabinet_group_link.cabinet_group
        _process_cabinet_links(bxf_cabinet_group.cabinet_links, cabinets)
      end
      cabinets
    end

    def _process_cabinet_links(bxf_cabinet_links, cabinets)
      bxf_cabinet_links.each do |bxf_cabinet_link|
        bxf_parameters = bxf_cabinet_link.parameters
        cabinets << {
          :object_id => bxf_cabinet_link.object_id,
          :description => bxf_cabinet_link.description,
          :width => _get_parameter_length(bxf_parameters['outerwidth']),
          :height => _get_parameter_length(bxf_parameters['height']),
          :depth => _get_parameter_length(bxf_parameters['depth']),
        }
      end
      cabinets
    end

    def _get_parameter_length(bxf_parameter)
      return nil unless bxf_parameter.is_a?(Bxf::BxfParameter)
      Bxf::BxfLength.new(bxf_parameter.model)
                    .read(bxf_parameter.value.to_s)
                    .to_l
    end

  end

end