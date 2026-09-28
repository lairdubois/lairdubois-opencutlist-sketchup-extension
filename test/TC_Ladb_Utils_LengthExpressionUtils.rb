require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/utils/length_expression_utils'

# The arithmetic of length expressions, shared by the VCB and the hardware
# descriptors. Literals and variables are read by plain lambdas : nothing
# here reads the model.
class TC_Ladb_Utils_LengthExpressionUtils < TestUp::TestCase

  LengthExpressionUtils = Ladb::OpenCutList::LengthExpressionUtils
  LengthExpressionError = LengthExpressionUtils::LengthExpressionError

  # Unchecked : every value is a plain number, like the VCB
  def _unchecked(text, variables = { '' => 100.0 })
    LengthExpressionUtils.evaluate(text,
                                   read_literal: lambda { |literal| [ literal.tr(',', '.').to_f, nil ] },
                                   read_variable: lambda { |name| [ variables.fetch(name), nil ] }).first
  end

  # Checked : a literal with 'L' is a length, a bare one a factor
  def _checked(text, variables = { 'thickness' => 19.0 })
    LengthExpressionUtils.evaluate(text,
                                   read_literal: lambda { |literal| literal.end_with?('m') ? [ literal.to_f, 1 ] : [ literal.to_f, 0 ] },
                                   read_variable: lambda { |name| [ variables.fetch(name), 1 ] })
  end

  def _assert_error(key, &block)
    block.call
    raise "expected #{key}, nothing raised"
  rescue LengthExpressionError => e
    assert_equal(key, e.key)
  end

  def test_arithmetic
    assert_equal(50.0, _unchecked('50'))
    assert_equal(10.0, _unchecked('+10'))
    assert_equal(-5.0, _unchecked('-5'))
    assert_equal(5.0, _unchecked('--5'))
    assert_equal(12.0, _unchecked('10 - -2'))
    assert_equal(-6.0, _unchecked('3*-2'))
    assert_equal(-10.0, _unchecked('-(5+5)'))
    assert_equal(14.0, _unchecked('2+3*4'))
    assert_equal(20.0, _unchecked('(2+3)*4'))
    assert_equal(2.0, _unchecked('8 / 2 / 2'))  # '8/2' alone is a fraction literal
    assert_equal(2.5, _unchecked('2,5'))
    assert_equal(50.0, _unchecked('  50  '))
  end

  def test_variables
    assert_equal(100.0, _unchecked('@'))
    assert_equal(110.0, _unchecked('@+10'))
    assert_equal(50.0, _unchecked('@/2'))
    assert_equal(-100.0, _unchecked('-@'))
    assert_equal(200.0, _unchecked('2 * @'))
    assert_equal([ 17.0, 1 ], _checked('@thickness - 2mm'))
    assert_equal([ 9.5, 1 ], _checked('@thickness / 2'))
    assert_equal([ -19.0, 1 ], _checked('-@thickness'))
    assert(LengthExpressionUtils.variables?('@thickness - 2mm'))
    assert(!LengthExpressionUtils.variables?('2mm'))
    assert_equal([ 'thickness', '' ], LengthExpressionUtils.variable_names('@thickness * @ - @thickness'))
  end

  def test_dimensions
    assert_equal([ 2.0, 0 ], _checked('@thickness / 9.5mm'))
    _assert_error('invalid_dimension') { _checked('@thickness + 2') }
    _assert_error('invalid_dimension') { _checked('@thickness * @thickness') }
    _assert_error('invalid_dimension') { _checked('2 / @thickness') }
    assert_equal(1000.0, _unchecked('10*(4+6)*10'))  # Unchecked : anything goes
  end

  def test_errors
    _assert_error('missing_close_parenthesis') { _unchecked('(5') }
    _assert_error('unexpected_close_parenthesis') { _unchecked('5)') }
    _assert_error('unexpected_close_parenthesis') { _unchecked('()') }
    _assert_error('missing_operand') { _unchecked('5+') }
    _assert_error('missing_operand') { _unchecked('*5') }
    _assert_error('missing_operand') { _unchecked('') }
    _assert_error('missing_operand') { _unchecked('5 +') }
    _assert_error('zero_division') { _unchecked('5/(2-2)') }
    _assert_error('syntax_error') { _unchecked('abc') }
    _assert_error('syntax_error') { _unchecked('5 exit') }
  end

  def test_functions
    assert_equal(10.0, _unchecked('min(10; 20)'))
    assert_equal(20.0, _unchecked('max(10; 20)'))
    assert_equal(5.0, _unchecked('min(10; 20; 5)'))
    assert_equal(25.0, _unchecked('MAX(5; 3) * 5'))
    assert_equal(30.0, _unchecked('max(min(10; 20); 30)'))
    assert_equal(-10.0, _unchecked('-max(10; 5)'))
    assert_equal(10.5, _unchecked('min(10,5; 20)'))              # ',' right in a number : a decimal separator
    assert_equal(10.0, _unchecked('min(10, 20)'))                # ',' right after an argument : a separator
    assert_equal([ 14.0, 1 ], _checked('min(@thickness - 5mm, 20mm)'))
    assert_equal([ 20.0, 1 ], _checked('max(20mm; 40mm - @thickness - 5mm)'))
    assert(LengthExpressionUtils.functions?('min(2mm; 3mm)'))
    assert(!LengthExpressionUtils.functions?('2mm'))
    _assert_error('invalid_argument_count') { _unchecked('min(10)') }
    _assert_error('invalid_dimension') { _checked('min(@thickness; 2)') }
    _assert_error('missing_close_parenthesis') { _unchecked('min(10; 20') }
    _assert_error('unexpected_close_parenthesis') { _unchecked('min(10;)') }
    _assert_error('missing_operand') { _unchecked('10; 20') }
    _assert_error('syntax_error') { _unchecked('sqrt(10; 20)') }
  end

  def test_steps
    assert_equal(12.0, _unchecked('floor(14; 12; 15; 20)'))
    assert_equal(15.0, _unchecked('floor(15; 12; 15; 20)'))
    assert_equal(20.0, _unchecked('ceil(18; 12; 15; 20)'))
    assert_equal(15.0, _unchecked('ceil(30 - 15; 20; 15; 12)'))   # Unordered steps
    assert_equal(12.0, _unchecked('floor(100; 12)'))
    assert_equal([ 12.0, 1 ], _checked('floor(@thickness - 5mm; 12mm; 15mm)'))
    _assert_error('no_matching_value') { _unchecked('floor(10; 12; 15)') }
    _assert_error('no_matching_value') { _unchecked('ceil(30; 12; 15)') }
    _assert_error('invalid_argument_count') { _unchecked('ceil(30)') }
    _assert_error('invalid_dimension') { _checked('floor(@thickness; 12)') }
  end

  def test_literals
    assert(LengthExpressionUtils.bare_number?('2,5'))
    assert(LengthExpressionUtils.bare_number?('3/4'))
    assert(!LengthExpressionUtils.bare_number?('3/4"'))
    assert(!LengthExpressionUtils.bare_number?('2 mm'))
    literals = []
    LengthExpressionUtils.evaluate(%q{1' 6" + 1 1/2" + 3/4" + 2.5 cm + 1yd + 5},
                                   read_literal: lambda { |literal| literals << literal; [ 0.0, nil ] },
                                   read_variable: lambda { |_| [ 0.0, nil ] })
    assert_equal([ %q{1' 6"}, '1 1/2"', '3/4"', '2.5 cm', '1yd', '5' ], literals)
  end

end
