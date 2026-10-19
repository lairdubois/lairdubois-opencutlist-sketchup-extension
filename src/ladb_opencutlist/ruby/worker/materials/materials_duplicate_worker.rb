module Ladb::OpenCutList

  class MaterialsDuplicateWorker

    def initialize(

                   name: ,
                   new_name:

    )

      @name = name
      @new_name = new_name

    end

    # -----

    def run

      model = Sketchup.active_model
      return { :errors => [ 'tab.materials.error.no_model' ] } unless model

      # Start a model modification operation
      model.start_operation('OCL Material Duplicate', true, false, true)

      materials = model.materials
      src_material = materials[@name]

      return { :errors => [ 'tab.materials.error.material_not_found' ] } unless src_material

      temp_dir = PLUGIN.temp_dir
      material_copy_dir = File.join(temp_dir, 'material_copy')
      unless Dir.exist?(material_copy_dir)
        Dir.mkdir(material_copy_dir)
      end
      uuid = SecureRandom.uuid
      filename = "#{uuid}.skm"
      path = File.join(material_copy_dir, filename)

      # Rename source material to random unique name (workaround to be sure that load SKM material name doesn't exist)
      src_material.name = uuid

      # Save source material to temp SKM file
      begin
        success = src_material.save_as(path)
        return { :errors => [ [ 'tab.materials.error.failed_duplicating_material', { :error => '' } ] ] } unless success
      rescue => e
        return { :errors => [ [ 'tab.materials.error.failed_duplicating_material', { :error => e.message } ] ] }
      ensure
        # Rename source material to its original name
        src_material.name = @name
      end

      # Load temp SKM file
      begin

        material = materials.load(path)

        # Change name
        new_name = Sketchup.version_number >= 1800000000 ? materials.unique_name(@new_name) : @new_name
        material.name = new_name

      rescue => e
        return { :errors => [ [ 'tab.materials.error.failed_duplicating_material', { :error => e.message } ] ] }
      ensure
        # Remove temp SKM file
        File.delete(path) if File.exist?(path)
      end

      # Commit model modification operation
      model.commit_operation

      { :id => material.entityID }
    end

    # -----

  end

end