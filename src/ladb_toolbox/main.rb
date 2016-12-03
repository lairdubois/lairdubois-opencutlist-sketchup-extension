require 'sketchup.rb'
require 'json'

module Ladb
  module Cutlist

    class Dim

      attr_accessor :length
      attr_accessor :width
      attr_accessor :thickness

      def initialize(length = 0, width = 0, thickness = 0)
        @length = length
        @width = width
        @thickness = thickness
      end

      def area
        @length * @width
      end

      def volume
        area * @thickness
      end

    end

    GroupDef = Struct.new(:name, :raw_thickness, :piece_defs )
    PieceDef = Struct.new(:name, :count, :raw_dim, :dim, :component_guids )

    # ==================================================== #

    $dialog = nil

    # ==================================================== #

    def self.ladb_fetch_leaf_components(entity, leaf_components)
      child_component_count = 0
      if entity.visible? and entity.layer.visible?
        if entity.is_a? Sketchup::Group
          entity.entities.each { |child_entity|
            child_component_count += ladb_fetch_leaf_components(child_entity, leaf_components)
          }
        elsif entity.is_a? Sketchup::ComponentInstance
          entity.definition.entities.each { |child_entity|
            child_component_count += ladb_fetch_leaf_components(child_entity, leaf_components)
          }
          if child_component_count == 0
            leaf_components.push(entity)
            return 1
          end
        end
      end
      child_component_count
    end

    def self.ladb_compute_faces_bounds(definition)
      bounds = Geom::BoundingBox.new
      definition.entities.each { |entity|
        if entity.is_a?Sketchup::Face
          bounds.add(entity.bounds)
        end
      }
      bounds
    end

    def self.ladb_dim_from_bounds(bounds)
      ordered = [ bounds.width, bounds.height, bounds.depth ].sort
      Dim.new(ordered[2], ordered[1], ordered[0])
    end

    def self.ladb_convert_to_std_thickness(thickness)
      std_thicknesses = [ '18mm'.to_l, '27mm'.to_l, '35mm'.to_l, '45mm'.to_l, '65mm'.to_l, '80mm'.to_l, '100mm'.to_l ]
      std_thicknesses.each { |standard_thickness|
        if thickness <= standard_thickness
          return standard_thickness;
        end
      }
      thickness
    end

    def self.ladb_generate_cutlist(entities, length_increase, width_increase, thickness_increase)

      # Fetch leaf components in given entities
      leaf_components = []
      entities.each { |entity|
        ladb_fetch_leaf_components(entity, leaf_components)
      }

      # Compute groups and pieces list of fetched components
      group_defs = {}
      leaf_components.each { |component|

        material = component.material
        definition = component.definition

        material_name = material ? component.material.name : 'Matière non définie'

        dim = ladb_dim_from_bounds(ladb_compute_faces_bounds(definition))
        raw_dim = Dim.new(
            (dim.length + length_increase).to_l,
            (dim.width + width_increase).to_l,
            ladb_convert_to_std_thickness((dim.thickness + thickness_increase).to_l)
        )

        key = material_name + ':' + raw_dim.thickness.to_s
        if not group_defs.has_key? key

          group_def = GroupDef.new
          group_def.name = material_name
          group_def.raw_thickness = raw_dim.thickness
          group_def.piece_defs = {}

          group_defs[key] = group_def

        else
          group_def = group_defs[key]
        end

        if not group_def.piece_defs.has_key? definition.name

          piece_def = PieceDef.new
          piece_def.name = definition.name
          piece_def.raw_dim = raw_dim
          piece_def.dim = dim
          piece_def.count = 0
          piece_def.component_guids = []

          group_def.piece_defs[definition.name] = piece_def

        else
          piece_def = group_def.piece_defs[definition.name]
        end
        piece_def.count += 1
        piece_def.component_guids.push(component.guid)

      }

      # Output JSON
      output = {
          :filepath => Sketchup.active_model.path,
          :length_unit => Sketchup.active_model.options['UnitsOptions']['LengthUnit'],
          :groups => []
      }

      # Sort and browse groups
      group_defs.sort_by { |k, v| [ v.raw_thickness ] }.reverse.each { |key, group_def|

        group = {
            :name => group_def.name,
            :raw_thickness => group_def.raw_thickness,
            :raw_area => 0,
            :raw_volume => 0,
            :pieces => []
        }
        output[:groups].push(group)

        # Sort and browse pieces
        group_def.piece_defs.sort_by { |k, v| [ v.dim.thickness, v.dim.length, v.dim.width ] }.reverse.each { |key, piece_def|
          group[:raw_area] += piece_def.raw_dim.area
          group[:raw_volume] += piece_def.raw_dim.volume
          group[:pieces].push({
                                  :count => piece_def.count,
                                  :raw_length => piece_def.raw_dim.length,
                                  :raw_width => piece_def.raw_dim.width,
                                  :length => piece_def.dim.length,
                                  :width => piece_def.dim.width,
                                  :thickness => piece_def.dim.thickness,
                                  :name => piece_def.name,
                                  :component_guids => piece_def.component_guids
                              }
          )
        }

      }

      JSON.generate(output)
    end

    def self.toggle_dialog

      if $dialog and $dialog.visible?
        $dialog.close
      else
        $dialog = UI::HtmlDialog.new(
            {
                :dialog_title => "L'Air du Bois - Boîte à outils Sketchup [BETA]",
                :preferences_key => "fr.lairdubois.plugin",
                :scrollable => true,
                :resizable => true,
                :width => 90,
                :height => 400,
                :left => 200,
                :top => 100,
                :min_width => 90,
                :style => UI::HtmlDialog::STYLE_DIALOG
            })
        $dialog.set_file(__dir__ + '/html/dialog.html')
        $dialog.set_size(90, 400)
        $dialog.add_action_callback("ladb_minimize") do |action_context|
          if $dialog
            $dialog.set_size(90, 400)
          end
        end
        $dialog.add_action_callback("ladb_maximize") do |action_context|
          if $dialog
            $dialog.set_size(1280, 800)
          end
        end
        $dialog.add_action_callback("ladb_generate_cutlist") do |action_context, json_params|

          params = JSON.parse(json_params)

          # Explode parameters
          callback = params['callback']
          length_increase = params['param']['length_increase'].to_l
          width_increase = params['param']['width_increase'].to_l
          thickness_increase = params['param']['thickness_increase'].to_l

          # Retrieve selected entities or all if no selection
          model = Sketchup.active_model
          if Sketchup.active_model.selection.empty?
            entities = model.active_entities
          else
            entities = model.selection
          end

          # Generate cutlist
          json_data = self.ladb_generate_cutlist(entities, length_increase, width_increase, thickness_increase)

          # Callback to JS
          $dialog.execute_script(callback.sub('%PARAM%', json_data))

        end
        $dialog.show
      end

    end


    # Setup menu #####

    unless file_loaded?(__FILE__)

      menu = UI.menu
      submenu = menu.add_submenu('L\'Air du Bois')
      submenu.add_item('Fiche de débit') {
        toggle_dialog
      }

      toolbar = UI::Toolbar.new('L\'Air du Bois')
      cmd = UI::Command.new('Boîte à outils') {
        toggle_dialog
      }
      cmd.small_icon = 'img/icon-72x72.png'
      cmd.large_icon = 'img/icon-114x114.png'
      cmd.tooltip = "Boîte à outils"
      cmd.status_bar_text = "Boîte à outils"
      cmd.menu_text = "Boîte à outils"
      toolbar = toolbar.add_item(cmd)
      toolbar.show

      # file_loaded(__FILE__)
    end

  end
end

