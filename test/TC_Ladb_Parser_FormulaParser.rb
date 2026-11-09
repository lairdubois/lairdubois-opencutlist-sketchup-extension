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

    assert_invalid_formula(<<~TXT
      __send__(:instance_variable_get, :@var1)
    TXT
    )

    assert_invalid_formula(<<~TXT
      public_send(:instance_variable_get, :@var1)
    TXT
    )

    assert_invalid_formula(<<~TXT
      method(:instance_variable_get).call(:@var1)
    TXT
    )

    assert_invalid_formula(<<~TXT
      instance_variable_get(:@var1)
    TXT
    )

    assert_invalid_formula(<<~TXT
      instance_exec { @var1 }
    TXT
    )

    assert_invalid_formula(<<~TXT
      define_singleton_method(:foo) { @var1 }
    TXT
    )

    assert_invalid_formula(<<~TXT
      1.class.const_get(:ObjectSpace)
    TXT
    )

    assert_invalid_formula(<<~TXT
      while true; end
    TXT
    )

    assert_invalid_formula(<<~TXT
      until false; end
    TXT
    )

    assert_invalid_formula(<<~TXT
      begin; end while true
    TXT
    )

    # Reaching a forbidden class through introspection, then `::`

    assert_invalid_formula(<<~TXT
      "".class.superclass::IO.popen("calc")
    TXT
    )

    assert_invalid_formula(<<~TXT
      "".class.superclass::File.read("/etc/hosts")
    TXT
    )

    assert_invalid_formula(<<~TXT
      "".class.ancestors.last::IO.popen("calc")
    TXT
    )

    assert_invalid_formula(<<~TXT
      @var1.class.superclass::ObjectSpace
    TXT
    )

    assert_invalid_formula(<<~TXT
      Date.superclass
    TXT
    )

    # Forbidden constant on the right side of `::` (top-level lookup through a class on Ruby < 2.5)

    assert_invalid_formula(<<~TXT
      Date::File.read("/etc/hosts")
    TXT
    )

    assert_invalid_formula(<<~TXT
      Time::IO.popen("calc")
    TXT
    )

    assert_invalid_formula(<<~TXT
      ::File.read("/etc/hosts")
    TXT
    )

    # Methods called indirectly through a symbol

    assert_invalid_formula(<<~TXT
      [ @var1 ].map(&:instance_variable_get)
    TXT
    )

    assert_invalid_formula(<<~TXT
      :"system"
    TXT
    )

    assert_invalid_formula(<<~TXT
      "system".to_sym
    TXT
    )

    assert_invalid_formula(<<~TXT
      :upcase.to_proc.call(@var1)
    TXT
    )

    # Reopening a whitelisted class

    assert_invalid_formula(<<~TXT
      Date.class_exec { attr_accessor :foo }
    TXT
    )

    assert_invalid_formula(<<~TXT
      Date.public_method(:today)
    TXT
    )

    # Console output

    assert_invalid_formula(<<~TXT
      p @var1
    TXT
    )

    assert_invalid_formula(<<~TXT
      @var1.display
    TXT
    )

    # VALID

    assert_valid_formula(<<~TXT
      1 + 2
    TXT
    )

    assert_valid_formula(<<~TXT
      my_var = @var1
      mat = @var2
      if !my_var.empty? && (m = /^var(.+)$/.match(mat.description))
        m[1].gsub('%ep%', mat.std_dimension)
      end
    TXT
    )

    assert_valid_formula(<<~TXT
      i = 0
      while i < 10
        i += 1
      end
      i
    TXT
    )

    # Whitelisted constants (and their own constants on the right side of `::`)

    assert_valid_formula(<<~TXT
      Math::PI * Math.sqrt(4)
    TXT
    )

    assert_valid_formula(<<~TXT
      Date::MONTHNAMES[Date.today.month]
    TXT
    )

    assert_valid_formula(<<~TXT
      Time.now.strftime("%Y-%m-%d")
    TXT
    )

    # Common string / array usage

    assert_valid_formula(<<~TXT
      @var1.upcase.gsub("A", "b").strip + " (" + @var1.length.to_s + ")"
    TXT
    )

    assert_valid_formula(<<~TXT
      [ 1, 2 ].map { |x| x * 2 }.join(", ")
    TXT
    )

    assert_valid_formula(<<~TXT
      { a: 1, "b" => 2 }["b"]
    TXT
    )

  end

  # Realistic formulas (UI snippets, common usages) that must stay accepted, and attacks that must stay refused
  def test_formula_corpus

    valid_formulas = [
      '@number + " - " + @name',
      '@bbox_length + " x " + @bbox_width',
      '@bbox_length * @bbox_width * @bbox_thickness',
      '@cabinet + "." + @part',
      '@number unless @material_type.is_hardware?',
      '@name',
      '@material.name + " " + @material.std_dimension',
      '@material.type.is_sheet_good? ? "P" : "B"',
      '@layers.join(", ")',
      '@layers.map(&:upcase).sort.join("/")',
      '@layers.map { |l| l.name }.uniq.first',
      '@component_definition.get_dc_attribute("lenx")',
      '@component_definition.get_attribute("dict", "key", "")',
      '@bbox_length.to_mm.round(1).to_s + " mm"',
      'format("%05.1f", @bbox_length.to_f)',
      '"#{@number}-#{@name}"',
      'Math.sqrt(@bbox_length ** 2 + @bbox_width ** 2)',
      'Math::PI',
      'Date.today.strftime("%d/%m/%Y")',
      'Time.now.year',
      'case @number when "A" then 1 when "B" then 2 else 3 end',
      'x = 0; [1, 2, 3].each { |i| x += i }; x',
      "i = 0\nwhile i < 10\n  i += 1\nend\ni",
      '@name =~ /(\d+)/ ? $1 : ""',
      '@name.split(/\s+/).map(&:capitalize).join(" ")',
      '[1, 2].inject(:+)',
      '@edge_ymin.material_name',
      'word_wrap(@name, 10)',
      '(1..5).to_a.sum',
      '@name[0, 3]',
      '%w[a b].include?(@number)',
      '@name.nil? || @name.empty? ? "-" : @name',
      'Integer("3") + Float("1.5")',
      '@batch.position.to_s + "/" + @batch.count.to_s',
      'h = { a: 1 }; h.keys.first',
      '!@name.empty? && @number != "B"',
      '-@bbox_length',
    ]

    invalid_formulas = [
      '"".class.superclass::IO.popen("calc")',
      'Date::File.read("/etc/hosts")',
      '::File.read("x")',
      'File.read("x")',
      '[@name].map(&:instance_variable_get)',
      ':"system"',
      '"system".to_sym',
      ':upcase.to_proc.call(@name)',
      'Date.class_exec { 1 }',
      'system("calc")',
      '`calc`',
      '%x(calc)',
      'eval("1")',
      'send(:system, "x")',
      '@name.send(:upcase)',
      '@name.public_send(:upcase)',
      'self',
      '$stdout',
      '@@x',
      '@unknown',
      'def x; end',
      '->(x) { x }',
      'lambda { 1 }',
      'proc { 1 }',
      'defined?(x)',
      'begin; 1; rescue; 2; end',
      '1 rescue 2',
      'while true; end',
      'begin; end while true',
      'x = 1, 2',
      'a, b = 1, 2',
      '@name = "x"',
      'X = 1',
      '@name.name = "x"',
      '@material.color.red = 1',
      'h = {}; h[:a] = 1',
      '[1].each(&method(:puts))',
      '@layers.map(&:class)',
      '[1].inject(:instance_eval)',
      'Kernel.exit',
      'ObjectSpace',
      'Math.const_get(:E)',
      'Time.at(0).class',
      'loop { 1 }',
      'Struct.new(:a)',
      '__FILE__',
      'BEGIN { 1 }',
      '@name.()',
      'case @name in String then 1 end',
      'return 1',
      'Date.new(2020, 1, 1).instance_variable_get(:@x)',
      'puts 1',
      'p 1',
      'h = { system: 1 }; h[:system]',   # Symbols must name a white listed method
    ]

    data = CorpusFormulaData.new
    valid_formulas.each { |formula| assert_valid_formula(formula, data) }
    invalid_formulas.each { |formula| assert_invalid_formula(formula, data) }

  end

  def test_white_lists_exclude_runtime_forbidden_methods
    parser_class = Ladb::OpenCutList::FormulaParser
    white_listed = parser_class::WHITE_LIST_METHOD + parser_class::WHITE_LIST_FUNCTION
    leaks = white_listed & parser_class::RUNTIME_FORBIDDEN_METHODS
    assert(leaks.empty?, "Forbidden methods in the white lists : #{leaks.join(', ')}")
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

  # Declares the variables used by the corpus (their values are irrelevant : the parser only checks they exist)
  class CorpusFormulaData < Ladb::OpenCutList::FormulaData

    def initialize
      @name = 'name'
      @number = 'A'
      @bbox_length = 1
      @bbox_width = 2
      @bbox_thickness = 3
      @material = nil
      @material_type = nil
      @layers = []
      @component_definition = nil
      @cabinet = 'cabinet'
      @part = 'part'
      @project = 'project'
      @batch = nil
      @edge_ymin = nil
    end

  end

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

