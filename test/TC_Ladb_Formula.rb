require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/parser/formula_parser'

class TC_Ladb_Formula < TestUp::TestCase

  def setup

  end

  def test_formula_parser

    assert_invalid_formula(<<-TXT
ENV['foo'] = "\0"
    TXT
    )

    assert_invalid_formula(<<-TXT
Process.spawn({'Foo' => '0'}, 'ruby -e "p ENV[\"Foo\"]"')
    TXT
    )

    assert_invalid_formula(<<-TXT
eval = eval("rm -fr /")
    TXT
    )

    assert_invalid_formula(<<-TXT
exec("dir")
    TXT
    )

    assert_invalid_formula(<<-TXT
dir = Dir.new('example')
    TXT
    )

    assert_invalid_formula(<<-TXT
IO.readlines("test.txt")
    TXT
    )

    assert_invalid_formula(<<-TXT
File.read("test.text")
    TXT
    )

    assert_invalid_formula(<<-TXT
File.write("c:\test.txt")
    TXT
    )

    assert_invalid_formula(<<-TXT
thr = Thread.new { puts "What's the big deal" }
    TXT
    )

    assert_invalid_formula(<<-TXT
q = Thread::Queue.new
    TXT
    )

    assert_invalid_formula(<<-TXT
throw "foo", "bar"
    TXT
    )

    assert_invalid_formula(<<-TXT
f=IO.popen('uname'); f.readlines; f.close
    TXT
    )

#     assert_invalid_formula(<<-TXT
# mat = @Matière
#
# descr = "CICA: what else"
# if !mat.empty? && (m = /^CICA:(.*)/.match(mat.description))
#   m[1]
# end
#     TXT
#     )

  end

  private

  def assert_invalid_formula(formula)
    assert_raises(InvalidFormulaError) do
      FormulaParser.parse(formula)
    end
  end

end

