module Ladb::OpenCutList

  require_relative '../../../lib/rubybxf/bxf'

  class ImportersBxf2LoadWorker

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
          :warnings => [],
          :errors => [],
          :path => @path,
          :filename => @filename,
          :length_unit => DimensionUtils.length_unit,
      }

      begin

        bxf_model = Bxf::BxfModel.load(@path)

        response[:model] = {
          :author => bxf_model.author,
          :date => bxf_model.date,
          :cabinets => _process_scene(bxf_model.scene, []),
          :articles => bxf_model.library.articles.map { |id, article| {
            :total_quantity => article.total_quantity,
            :article_number => article.article_number,
            :description => article.description,
          } },
        }

      rescue Exception => e
        PLUGIN.dump_exception(e)
        response[:errors] << [ 'tab.importers.bxf2.error.failed_to_load_bxf2_file', { :error => e.message } ]
        return response
      end

      [ response, bxf_model, @path ]
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