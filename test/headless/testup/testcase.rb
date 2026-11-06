# A stand-in for TestUp::TestCase, to run TestUp suites outside SketchUp
# through test/headless/run.rb. NEVER load it inside SketchUp.
module TestUp

  class AssertionFailed < StandardError; end

  class TestCase

    def setup; end

    def teardown; end

    def assert(value, message = nil)
      raise AssertionFailed, (message || 'assertion failed') unless value
      true
    end

    def refute(value, message = nil)
      assert(!value, message || "expected #{value.inspect} to be falsy")
    end

    def assert_equal(expected, actual, message = nil)
      assert(expected == actual, message || "expected #{expected.inspect}, got #{actual.inspect}")
    end

    def assert_nil(value, message = nil)
      assert(value.nil?, message || "expected nil, got #{value.inspect}")
    end

    def refute_nil(value, message = nil)
      assert(!value.nil?, message || 'expected not nil')
    end

    def assert_in_delta(expected, actual, delta = 0.001, message = nil)
      assert((expected.to_f - actual.to_f).abs <= delta.to_f, message || "expected #{expected.inspect} ± #{delta}, got #{actual.inspect}")
    end

    def assert_kind_of(klass, value, message = nil)
      assert(value.is_a?(klass), message || "expected a #{klass}, got #{value.class}")
    end

    def assert_includes(collection, value, message = nil)
      assert(collection.include?(value), message || "expected #{collection.inspect} to include #{value.inspect}")
    end

    # Returns the exception, like Minitest
    def assert_raises(*classes)
      yield
    rescue *classes => e
      e
    else
      raise AssertionFailed, "expected #{classes.join(' or ')} to be raised"
    end

  end

end
