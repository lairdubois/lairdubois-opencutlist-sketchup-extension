require 'testup/testcase'

# What the VCB reads as a length - UserTextHelper#_read_user_text_length -
# in a model in millimeters then in inches : a bare number is in model
# units. Runs in SketchUp - String#to_l, model units - the units of the
# active model are restored after each test.
class TC_Ladb_Helper_UserTextHelper < TestUp::TestCase

  MILLIMETER = 2
  INCHES = 0

  # [ text, targeted length in model units, expected in mm in a mm model,
  #   expected in mm in an inch model ] - nil = refused
  CASES = [
    [ '', 100, 100.0, 2540.0 ],
    [ '50', 0, 50.0, 1270.0 ],
    [ ' 50 ', 0, 50.0, 1270.0 ],
    [ '+10', 0, 10.0, 254.0 ],
    [ '-5', 0, -5.0, -127.0 ],
    [ '--5', 0, 5.0, 127.0 ],
    [ '-(5+5)', 0, -10.0, -254.0 ],
    [ '5-3', 0, 2.0, 50.8 ],
    [ '10 - -2', 0, 12.0, 304.8 ],
    [ '3*-2', 0, -6.0, -152.4 ],
    [ '2*3', 0, 6.0, 152.4 ],
    [ '10/4', 0, 2.5, 63.5 ],
    [ '2.5', 0, 2.5, 63.5 ],
    [ '@', 100, 100.0, 2540.0 ],
    [ '@+10', 100, 110.0, 2794.0 ],
    [ '@-15', 100, 85.0, 2159.0 ],
    [ '@*3', 100, 300.0, 7620.0 ],
    [ '@/2', 100, 50.0, 1270.0 ],
    [ '-@', 100, -100.0, -2540.0 ],
    [ '2 * @', 100, 200.0, 5080.0 ],
    [ '@', -100, -100.0, -2540.0 ],
    [ '@+10', -100, -110.0, -2794.0 ],
    [ '2m*(2+3)', 0, 10000.0, 10000.0 ],
    [ '10cm', 0, 100.0, 100.0 ],
    [ '50mm', 0, 50.0, 50.0 ],
    [ '1cm+5', 0, 15.0, 137.0 ],
    [ '1"', 0, 25.4, 25.4 ],
    [ "1'", 0, 304.8, 304.8 ],
    [ %q{1' 6"}, 0, 457.2, 457.2 ],
    [ '3/4"', 0, 19.05, 19.05 ],
    [ '1 1/2"', 0, 38.1, 38.1 ],
    [ '(5', 0, nil, nil ],
    [ '5)', 0, nil, nil ],
    [ '5+', 0, nil, nil ],
    [ '5/0', 0, nil, nil ],
    [ 'abc', 0, nil, nil ],
    [ '@x', 100, nil, nil ],
  ].freeze

  class ToolStub
    attr_reader :errors
    def initialize; @errors = []; end
    def notify_errors(errors); @errors.concat(errors); end
  end

  def setup
    @model = Sketchup.active_model
    @units = @model.options['UnitsOptions']
    @saved = %w[LengthUnit LengthFormat].map { |key| [ key, @units[key] ] }
    @units['LengthFormat'] = 0  # Decimal
    @helper = Object.new.extend(Ladb::OpenCutList::UserTextHelper)
  end

  def teardown
    @saved.each { |key, value| @units[key] = value }
    Ladb::OpenCutList::DimensionUtils.fetch_options
  end

  def test_millimeters
    _assert_cases(MILLIMETER, 2)
  end

  def test_inches
    _assert_cases(INCHES, 3)
  end

  def test_decimal_comma
    return unless Ladb::OpenCutList::DimensionUtils.decimal_separator == ','
    _set_unit(MILLIMETER)
    assert_in_delta(2.5, _read('2,5', 0).to_f * 25.4, 1e-6)
  end

  def test_errors_are_notified
    _set_unit(MILLIMETER)
    tool = ToolStub.new
    assert_nil(@helper._read_user_text_length(tool, '(5', 0))
    assert_equal('tool.default.error.invalid_length', tool.errors.first.first)
    assert_equal('tool.default.error.syntax_error', tool.errors[1].first)
    tool = ToolStub.new
    assert_nil(@helper._read_user_text_length(tool, '5/(2-2)', 0))
    assert_equal('tool.default.error.zero_division', tool.errors[1].first)
  end

  private

  def _set_unit(unit)
    @units['LengthUnit'] = unit
    Ladb::OpenCutList::DimensionUtils.fetch_options
  end

  def _read(text, targeted)
    @helper._read_user_text_length(ToolStub.new, text, targeted)
  end

  def _assert_cases(unit, column)
    _set_unit(unit)
    failures = CASES.map { |row|
      text, targeted, expected = row[0], row[1], row[column]
      targeted = unit == MILLIMETER ? targeted.mm : targeted.to_f
      value = _read(text, targeted)
      actual = value.nil? ? nil : (value.to_f * 25.4).round(4)
      ok = expected.nil? ? actual.nil? : !actual.nil? && (actual - expected).abs < 1e-3
      ok ? nil : "#{text.inspect} (@ = #{row[1]}) : expected #{expected.inspect}, got #{actual.inspect}"
    }.compact
    assert(failures.empty?, failures.join("\n"))
  end

end
