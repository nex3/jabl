require 'rubygems'
require 'enumerator'
require 'scanner'
#require 'lexer'
#require 'grammar'
#require 'parse_node'

class Jabl
  Line = Struct.new(:text, :tabs, :index)
  Node = Struct.new(:text, :index, :children, :next, :prev, :parsed, :scanner)

  DIRECT_BLOCK_STATEMENTS = %w[while for with]

  def initialize(string)
    @tree, _ = tree(tabulate(string))
    parse_nodes @tree
  end

  def render
    "_jabl_context = $(document);\n" +
      @tree.map {|n| compile(n, 0)}.join
  end

  def pretty_inspect(nodes = @tree, tabs = 0)
    nodes.map do |n|
      ('  ' * tabs) + n.text + "\n" + pretty_inspect(n.children, tabs + 1)
    end.join
  end

  def inspect(nodes = @tree, tabs = 0)
    nodes.map do |n|
      n.text + (n.children.empty? ? '' : '(' + inspect(n.children, tabs + 1) + ')')
    end.join(',')
  end

  def parse_tree
    @tree
  end

  private

  def compile(node, tabs)
    return '' if node.parsed
    if node.children.empty?
      if node.scanner.scan /\./; compile_scoped node, tabs
      elsif node.scanner.keyword :switch; compile_switch node, tabs
      else tabs(tabs) + node.text + ";\n"
      end
    else
      DIRECT_BLOCK_STATEMENTS.each do |name|
        return compile_block(name, node, tabs) if node.scanner.keyword name
      end

      if node.scanner.keyword :fun; compile_fun node, tabs
      elsif node.scanner.keyword :if; compile_if node, tabs
      elsif node.scanner.keyword :do; compile_do_while node, tabs
      elsif node.scanner.keyword :try; compile_try node, tabs
      elsif node.scanner.keyword :let; parse_let node, tabs
      elsif node.scanner.scan /\$/; compile_selector node, tabs
      elsif node.scanner.scan /\:/; compile_event node, tabs
      else; raise "Invalid parse node: #{node.text.inspect}"
      end
    end
  end

  def compile_nodes(nodes, tabs)
    nodes.map {|n| compile(n, tabs)}.join
  end

  def compile_fun(node, tabs)
    node.scanner.whitespace!
    name = node.scanner.identifier!

    args = []
    if node.scanner.scan(/\(/)
      loop do
        node.scanner.whitespace
        args << node.scanner.identifier!
        node.scanner.whitespace
        unless node.scanner.scan(/,/)
          node.scanner.scan!(/\)/)
          break
        end
      end
    end

    <<END
#{tabs(tabs)}function #{name}(#{args.join(', ')}) {
#{compile_nodes(node.children, tabs + 1)}#{tabs(tabs)}}
END
  end

  def compile_if(node, tabs)
    str = compile_block('if', node, tabs)
    while node.next && node.next.scanner.keyword(:else)
      node = node.next
      node.parsed = true
      str.rstrip! << ' ' << compile_else(node, tabs)
    end
    str
  end

  def compile_else(node, tabs)
    if node.scanner.whitespace
      node.scanner.keyword! 'if'
      compile_block('else if', node, tabs).lstrip
    else
      <<END
else {
#{compile_nodes(node.children, tabs + 1)}}
END
    end
  end

  def compile_do_while(node, tabs)
    next_node = node.next
    next_node.scanner.keyword! 'while'
    next_node.scanner.whitespace!
    exp = next_node.scanner.scan!(/.+/)
    next_node.parsed = true

    <<END
#{tabs(tabs)}do {
#{compile_nodes(node.children, tabs + 1)}} while (#{exp});
END
  end

  def compile_switch(node, tabs)
    node.scanner.whitespace!
    str = <<END
#{tabs(tabs)}switch (#{node.scanner.scan!(/.+/)}) {
END

    while node = node.next
      if node.scanner.keyword(:case)
        node.parsed = true
        node.scanner.whitespace!
        clause = "case #{node.scanner.scan!(/.+/)}"
      elsif node.scanner.keyword(:default)
        node.parsed = true
        clause = "default"
      else
        break
      end

      str << <<END
#{tabs(tabs)}#{clause}:
#{compile_nodes(node.children, tabs + 1).rstrip}
END
    end

    str + tabs(tabs) + "}\n"
  end

  def compile_try(node, tabs)
    node.scanner.eos!
    str = <<END
#{tabs(tabs)}try {
#{compile_nodes(node.children, tabs + 1)}#{tabs(tabs)}}
END

    if node.next && node.next.scanner.keyword(:catch)
      node = node.next
      node.parsed = true
      str.rstrip! << ' ' << compile_block(:catch, node, tabs).lstrip
    end

    if node.next && node.next.scanner.keyword(:finally)
      node = node.next
      node.parsed = true
      str.rstrip! << ' ' << <<END
finally {
#{compile_nodes(node.children, tabs + 1)}#{tabs(tabs)}}
END
    end

    str
  end

  def parse_let(node, tabs)
    node.scanner.whitespace!

    terms = []
    loop do
      term = []
      node.scanner.whitespace
      term << node.scanner.identifier!
      node.scanner.whitespace
      node.scanner.scan!(/=/)
      node.scanner.whitespace
      term << node.scanner.scan!(/[^,]+/) # TODO: Actually parse expression
      terms << term
      unless node.scanner.scan(/,/)
        node.scanner.eos!
        break
      end
    end

    compile_let(terms, tabs, node.children)
  end

  def compile_block(name, node, tabs)
    node.scanner.whitespace!

    <<END
#{tabs(tabs)}#{name} (#{node.scanner.scan!(/.+/)}) {
#{compile_nodes(node.children, tabs + 1)}#{tabs(tabs)}}
END
  end

  def compile_selector(node, tabs)
    compile_context("$(#{node.scanner.scan!(/.+/).inspect})", tabs, node.children)
  end

  def compile_context(var, tabs, children)
    compile_let([[:_jabl_context, var]], tabs, children)
  end

  def compile_let(vars, tabs, children)
    <<END
#{tabs(tabs)}(function(#{vars.map {|n, v| n}.join(", ")}) {
#{compile_nodes(children, tabs + 1)}#{tabs(tabs)})(#{vars.map {|n, v| v}.join(", ")});
END
  end

  def compile_scoped(node, tabs)
    "#{tabs(tabs)}_jabl_context.#{node.scanner.scan!(/.+/)};\n"
  end

  def compile_event(node, tabs)
    event = node.scanner.identifier!
    if node.scanner.scan(/\(/)
      node.scanner.whitespace
      var = event.scanner.identifier
      node.scanner.whitespace
      node.scanner.scan!(/\)/)
    end
    node.scanner.eos!

    <<END
#{tabs(tabs)}_jabl_context.on(#{event.inspect}, function(#{var.inspect if var}) {
#{compile_nodes(node.children, tabs + 1)}#{tabs(tabs)}});
END
  end

  def tabulate(string)
    tab_str = nil
    string.scan(/^.*?$/).enum_with_index.map do |line, index|
      next if line.strip.empty?

      line_tab_str = line[/^\s*/]
      tab_str ||= line_tab_str unless line_tab_str.empty?
      next Line.new(line.strip, 0, index) if tab_str.nil?

      line_tabs = line_tab_str.scan(tab_str).size
      raise "Inconsistent indentation" if tab_str * line_tabs != line_tab_str

      Line.new(line.strip, line_tabs, index)
    end.compact
  end

  def tree(arr, i = 0)
    base = arr[i].tabs
    nodes = []
    while (line = arr[i]) && line.tabs >= base
      if line.tabs > base
        nodes.last.children, i = tree(arr, i)
      else
        nodes << Node.new(line.text, line.index, [])
        i += 1
      end
    end
    return nodes, i
  end

  def parse_nodes(nodes)
    nodes.each_cons(2) do |n, s|
      n.next = s
      s.prev = n if s
    end
    nodes.each do |n|
      n.children = parse_nodes(n.children)
      n.scanner = Scanner.new(n.text)
      #_, n.parsed = ParseNode.from_node(NestParser.parse(NestLexer.lex(n.text)))
    end
  end

  def tabs(tabs)
    '  ' * tabs
  end
end

puts Jabl.new($stdin.read).render if $0 == __FILE__
