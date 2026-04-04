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
      return { :errors => [ 'tab.importer.default.error.no_model' ] } unless model

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
          :cabinets => bxf_model.library.cabinets.map { |id, cabinet| { :description => cabinet.description } },
          :articles => bxf_model.library.articles.map { |id, article| { :description => article.description, :total_quantity => article.total_quantity } },
        }

      rescue Exception => e
        response[:errors] << [ 'tab.importer.bxf2.error.failed_to_load_bxf2_file', { :error => e.message } ]
        return response
      end

      [ response, bxf_model, @path ]
    end

    # -----

  end

end