module Ladb::OpenCutList

  require 'test/unit'
  require 'sketchup.rb'
  require_relative '../src/ladb_opencutlist/ruby/utils/dimension_utils'

  class DimensionUtilsTest < Test::Unit::TestCase

    # Called before every test method runs. Can be used
    # to set up fixture information.
    def setup
      # Do nothing
    end

    # Called after every test method runs. Can be used to tear
    # down fixture information.

    def teardown
      # Do nothing
    end

    # Fake test
    def test_fail
      fail('Not implemented')
    end

    def test_one
      result = DimensionUtils.instance.prefix_marker('0')
      assert(result.eql?('d:0'), "Expected 'd:0' but was #{result}" )
    end

  end

end
