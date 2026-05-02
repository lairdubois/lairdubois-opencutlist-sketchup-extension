module Ladb::OpenCutList

  class ImportersBxf2CabinetLinkUpdateWorker

    def initialize(bxf_model,

                   object_id:,
                   description:

    )

      @bxf_model = bxf_model

      @object_id = object_id
      @description = description

    end

    # -----

    def run

      return { :errors => [ 'tab.importers.default.error.no_data' ] } unless @bxf_model.is_a?(Bxf::BxfModel)


      cabinet_link = _process_scene(@bxf_model.scene)
      return { :errors => [ 'tab.importers.default.error.no_data' ] } if cabinet_link.nil?

      cabinet_link.description = @description

      {
        :description => @description
      }
    end

    # -----

    def _process_scene(bxf_scene)
      if (cabinet_link = _process_nodes(bxf_scene.nodes))
        return cabinet_link
      end
      nil
    end

    def _process_nodes(bxf_nodes)
      bxf_nodes.each do |bxf_node|
        if (cabinet_link = _process_node(bxf_node))
          return cabinet_link
        end
      end
      nil
    end

    def _process_node(bxf_node)
      if (cabinet_link = _process_cabinet_group_links(bxf_node.cabinet_group_links))
        return cabinet_link
      end
      if (cabinet_link = _process_cabinet_links(bxf_node.cabinet_links))
        return cabinet_link
      end
      if (cabinet_link = _process_nodes(bxf_node.nodes))
        return cabinet_link
      end
      nil
    end

    def _process_cabinet_group_links(bxf_cabinet_group_links)
      bxf_cabinet_group_links.each do |bxf_cabinet_group_link|
        bxf_cabinet_group = bxf_cabinet_group_link.cabinet_group
        if (cabinet_link = _process_cabinet_links(bxf_cabinet_group.cabinet_links))
          return cabinet_link
        end
      end
      nil
    end

    def _process_cabinet_links(bxf_cabinet_links)
      bxf_cabinet_links.each do |bxf_cabinet_link|
        return bxf_cabinet_link if bxf_cabinet_link.object_id == @object_id
      end
      nil
    end

  end

end
