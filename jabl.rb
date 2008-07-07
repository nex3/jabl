require 'rubygems'
require 'enumerator'
require 'scanner'
#require 'lexer'
#require 'grammar'
#require 'parse_node'

class Jabl
  Line = Struct.new(:text, :tabs, :index)
  Node = Struct.new(:text, :index, :children, :scanner)

  DIRECT_BLOCK_STATEMENTS = [if while for with]

  def initialize(string)
    @tree, _ = tree(tabulate(string))
    parse_nodes @tree
  end

  def render
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
    if node.children.empty?
      if node.scanner.scan /\./; compile_scoped node, tabs
      else tabs(tabs) + node.text + ";\n"
      end
    else
      DIRECT_BLOCK_STATEMENTS.each do |name|
        return compile_block name, node, tabs if node.scanner.keyword name
      end

      if node.scanner.keyword :fun; compile_fun node, tabs
      elsif node.scanner.scan /\$/; compile_selector node, tabs
      elsif node.scanner.scan /\:/; compile_event node, tabs
      else; raise "Invalid parse node: #{node.inspect}"
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
        node.scanner.whitespace?
        args << node.scanner.identifier!
        node.scanner.whitespace?
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

  def compile_block(name, node, tabs)
    node.scanner.whitespace!

    <<END
#{tabs(tabs)}#{name} (#{node.scanner.scan!(/.+/)}) {
#{compile_nodes(node.children, tabs + 1)}#{tabs(tabs)}}
END
  end

  def compile_selector(node, tabs)
    compile_context("$(#{node.scanner.scan!(/.+/).inspect})", tabs) { |t| compile_nodes(node.children, t) }
  end

  def compile_context(var, tabs, &block)
    compile_let({:_jabl_context => var}, tabs, &block)
  end

  def compile_let(vars, tabs)
    <<END
#{tabs(tabs)}(function(#{vars.keys.join(", ")}) {
#{yield(tabs + 1)}})(#{vars.values.join(", ")});
END
  end

  def compile_scoped(node, tabs)
    "#{tabs(tabs)}_jabl_context.#{node.scanner.scan!(/.+/)};\n"
  end

  def compile_event(node, tabs)
    event = node.scanner.identifier!
    if node.scanner.scan(/\(/)
      node.scanner.whitespace?
      var = event.scanner.identifier
      node.scanner.whitespace?
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
