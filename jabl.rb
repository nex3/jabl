require 'rubygems'
require 'enumerator'
require 'scanner'
#require 'lexer'
#require 'grammar'
#require 'parse_node'

class Jabl
  Line = Struct.new(:text, :tabs, :index)
  Node = Struct.new(:text, :index, :children, :scanner)

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
    return tabs(tabs) + node.text + ";\n" if node.children.empty?

    if node.scanner.keyword :fun; compile_fun node, tabs
    else; raise "Invalid parse node: #{node.inspect}"
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
