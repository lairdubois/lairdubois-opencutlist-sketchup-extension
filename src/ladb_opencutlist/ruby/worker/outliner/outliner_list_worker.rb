module Ladb::OpenCutList

  require_relative '../../model/outliner/node'

  class OutlinerListWorker

    def initialize(settings)

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.outliner.error.no_model' ] } unless model
      return { :errors => [ 'tab.outliner.error.no_entities' ] } if model.entities.length == 0

      root_node = Node.new(model.guid)
      root_node.name = model.name

      _append_entities(model.entities, root_node)

      response = {
        :errors => [],
        :warnings => [],
        :filename => !model.path.empty? ? File.basename(model.path) : Plugin.instance.get_i18n_string('default.empty_filename'),
        :model_name => model.name,
        :length_unit_strippedname => DimensionUtils.instance.model_unit_is_metric ? DimensionUtils::UNIT_STRIPPEDNAME_METER : DimensionUtils::UNIT_STRIPPEDNAME_FEET,
        :mass_unit_strippedname => MassUtils.instance.get_symbol,
        :currency_symbol => PriceUtils.instance.get_symbol,
        :root_node => root_node.to_hash
      }

      response
    end

    # -----

    def _append_entities(entities, parent)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)

          node = Node.new(entity.guid)
          node.name = entity.name
          node.name = "#{entity.name} <#{entity.definition.name}>".strip if entity.is_a?(Sketchup::ComponentInstance)

          if entity.is_a?(Sketchup::Group)
            _append_entities(entity.entities, node)
          elsif entity.is_a?(Sketchup::ComponentInstance)
            _append_entities(entity.definition.entities, node)
          end

          parent.nodes << node

        end
      end
    end

  end

end