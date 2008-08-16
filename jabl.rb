require 'rubygems'
require 'enumerator'
require 'node'

class Jabl
  Line = Struct.new(:text, :tabs, :index)

  DIRECT_BLOCK_STATEMENTS = %w[while for with].map {|s| s.to_sym}

  attr :jabl_context
  private :jabl_context

  def initialize(string)
    @tree, _ = tree(tabulate(string))
  end

  def render
    let_context("_jabl_context") do
      "#{jabl_context} = $(document);\n" +
        @tree.map {|n| compile(n, 0)}.join
    end
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
    return if node.parsed?
    case node.name
    when *DIRECT_BLOCK_STATEMENTS; compile_block(name, node, tabs)
    when :scoped; compile_scoped node, tabs
    when :switch; compile_switch node, tabs
    when :text; tabs(tabs) + compile_text(node[:text]) + ";\n"
    when :fun; compile_fun node, tabs
    when :if; compile_if node, tabs
    when :do; compile_do_while node, tabs
    when :try; compile_try node, tabs
    when :let; compile_let node[:terms], tabs, node.children
    when :selector; compile_selector node, tabs
    when :event; compile_event node, tabs
    else; raise "Invalid parse node: #{node.text.inspect}"
    end
  end

  def compile_nodes(nodes, tabs)
    nodes.map {|n| compile(n, tabs)}.join
  end

  def compile_fun(node, tabs)
    <<END
#{tabs(tabs)}function #{node[:name]}(#{node[:args].join(', ')}) {
#{compile_nodes(node.children, tabs + 1)}#{tabs(tabs)}}
END
  end

  def compile_if(node, tabs)
    compile_block(node, tabs).rstrip + node[:else].map {|n| compile_else(n, tabs)}.join + "\n"
  end

  def compile_else(node, tabs)
    " " + compile_block(node, tabs, 'else' + (node[:expr] ? ' if' : '')).rstrip
  end

  def compile_do_while(node, tabs)
    compile_block(node, tabs).lstrip + " while (#{compile_text(node[:expr])});"
  end

  def compile_switch(node, tabs)
    str = <<END
#{tabs(tabs)}switch (#{compile_text(node[:expr])}) {
END

    node[:cases].each do |n|
      str << tabs(tabs)
      if n.name == :default
        str << "default"
      else
        str << "case #{compile_text(n[:expr])}"
      end
      str << ":\n" << compile_nodes(n.children, tabs + 1)
    end

    str << tabs(tabs) << "}\n"
  end

  def compile_try(node, tabs)
    str = compile_block(node, tabs)

    if node[:catch]
      str.rstrip!
      str << ' ' << compile_block(node[:catch],   tabs).lstrip
    end

    if node[:finally]
      str.rstrip!
      str << ' ' << compile_block(node[:finally], tabs).lstrip
    end

    str
  end

  def compile_block(node, tabs, name = node.name)
    tabs(tabs) + name.to_s + (node[:expr] && " (#{compile_text(node[:expr])})").to_s + " {\n" +
      compile_nodes(node.children, tabs + 1) + tabs(tabs) + "}"
  end

  def compile_selector(node, tabs)
    compile_context("$(#{node[:text].inspect})", tabs, node.children)
  end

  def compile_context(var, tabs, children)
    if children.inject(0) {|s, c| s + c.context_refs} < 2
      let_context(var) { compile(children.first, tabs) }
    else
      let_context("_jabl_context") { compile_let([[:_jabl_context, var]], tabs, children) }
    end
  end

  def compile_let(vars, tabs, children)
    <<END
#{tabs(tabs)}(function(#{vars.map {|n, v| n}.join(", ")}) {
#{compile_nodes(children, tabs + 1)}#{tabs(tabs)}})(#{vars.map {|n, v| v}.join(", ")});
END
  end

  def compile_scoped(node, tabs)
    "#{tabs(tabs)}#{jabl_context}.#{compile_text(node[:text])};\n"
  end

  def compile_event(node, tabs)
    node[:name] = "load" if node[:name] == "ready"
    <<END
#{tabs(tabs)}#{jabl_context}.on(#{node[:name].inspect}, function(#{node[:var]}) {
#{compile_nodes(node.children, tabs + 1)}#{tabs(tabs)}});
END
  end

  def compile_text(text)
    text.gsub(/\@([^ ]*) = (.*)/) do |match|
      "#{jabl_context}.attr(#{$1.inspect}: #{$2})"
    end.gsub(/@([A-z_])*/) do |match|
      "#{jabl_context}.attr(#{$1.inspect})"
    end
  end

  def let_context(str)
    str, @jabl_context = @jabl_context, str
    res = yield
    str, @jabl_context = @jabl_context, str    
    res
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
    raw_next = lambda do
      line = arr[i]
      line.raw_next = raw_next
      i += 1
      line
    end
    peek_next = lambda do
      break nil unless (line = arr[i]) && line.tabs >= base
      if line.tabs > base
        nodes.last.children, i = tree(arr, i)
        peek_next.call
      else
        node = Node.new(line.text, line.index, [])
        node.raw_next = raw_next
        node.peek_next = peek_next
        node.getter = lambda do
          i += 1
          nodes << node
        end
        node
      end
    end

    while node = peek_next.call
      node.get!
      node.parsed = false
      node.parse!
    end
    return nodes, i
  end

  def tabs(tabs)
    '  ' * tabs
  end
end

puts Jabl.new($stdin.read).render if $0 == __FILE__
