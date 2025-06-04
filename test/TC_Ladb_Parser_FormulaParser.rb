require 'testup/testcase'

require_relative '../src/ladb_opencutlist/ruby/model/formula/formula_data'
require_relative '../src/ladb_opencutlist/ruby/parser/formula_parser'

class TC_Ladb_Parser_FormulaParser < TestUp::TestCase

  def setup
  end

  def test_formula_parser

    # INVALID

    assert_invalid_formula(<<~TXT
      ENV['foo'] = "\0"
    TXT
    )

    assert_invalid_formula(<<~TXT
      $stdout.puts("hello, from $stdout")
    TXT
    )

    assert_invalid_formula(<<~TXT
      STDOUT.puts("hello, from STDOUT")
    TXT
    )

    assert_invalid_formula(<<~TXT
      Process.spawn({'Foo' => '0'}, 'ruby -e "p ENV[\"Foo\"]"')
    TXT
    )

    assert_invalid_formula(<<~TXT
      eval = eval("rm -fr /")
    TXT
    )

    assert_invalid_formula(<<~TXT
      eval("`dir`")
    TXT
    )

    assert_invalid_formula(<<~TXT
      eval("File.open('test.txt')"))
    TXT
  )

    assert_invalid_formula(<<~TXT
      Object.send(:to_s)
    TXT
    )

    assert_invalid_formula(<<~TXT
      Object.send :to_s
    TXT
    )

    assert_invalid_formula(<<~TXT
      exec("dir")
    TXT
    )

    assert_invalid_formula(<<~TXT
      dir = Dir.new('example')
    TXT
    )

    assert_invalid_formula(<<~TXT
      IO.readlines("test.txt")
    TXT
    )

    assert_invalid_formula(<<~TXT
      File.read("test.text")
    TXT
    )

    assert_invalid_formula(<<~TXT
      File.write("c:\test.txt")
    TXT
    )

    assert_invalid_formula(<<~TXT
      Dir.children("not_empty_directory")
    TXT
    )

    assert_invalid_formula(<<~TXT
      FileUtils.rm Dir.glob('*.so')
    TXT
    )

    assert_invalid_formula(<<~TXT
      thr = Thread.new { puts "What's the big deal" }
    TXT
    )

    assert_invalid_formula(<<~TXT
      q = Thread::Queue.new
    TXT
    )

    assert_invalid_formula(<<~TXT
      throw "foo", "bar"
    TXT
    )

    assert_invalid_formula(<<~TXT
      f=IO.popen('uname'); f.readlines; f.close
    TXT
    )

    assert_invalid_formula(<<~TXT
      `ls`
    TXT
    )

    assert_invalid_formula(<<~TXT
      %x[ls]
    TXT
    )

    assert_invalid_formula(<<~TXT
      <<-`CMD`
        ls
      CMD
    TXT
    )

    assert_invalid_formula(<<~TXT
      module A; class B; end; end
    TXT
    )

    assert_invalid_formula(<<~TXT
      Kernel.send(:exit)
    TXT
    )

    assert_invalid_formula(<<~TXT
      puts @var3
    TXT
    )

    assert_invalid_formula(<<~TXT
      alias_method :exit :go_out
    TXT
    )

    # VALID

    assert_valid_formula(<<~TXT
      1 + 2
    TXT
    )

    assert_valid_formula(<<~TXT
      my_var = @var1
      if !my_var.empty? && (m = /^var(.+)$/.match(mat.description))
        m[1].gsub('%ep%', mat.std_dimension)
      end
    TXT
    )


  end

  private

  def assert_invalid_formula(formula, data = TestFormulatData.new)
    assert_raises(Ladb::OpenCutList::ForbiddenFormulaError) do
      Ladb::OpenCutList::FormulaParser.new(formula, data).parse
    end
  end

  def assert_valid_formula(formula, data = TestFormulatData.new)
    begin
      assert Ladb::OpenCutList::FormulaParser.new(formula, data).parse
    rescue Ladb::OpenCutList::ForbiddenFormulaError => e
      assert(false, "Invalid formula : #{e.message}")
    end
  end

  # --

  class TestFormulatData < Ladb::OpenCutList::FormulaData

    def initialize(
      var1: 'var1',
      var2: 2
    )
      @var1 = var1
      @var2 = var2
    end

  end

end

