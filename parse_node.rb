class Jabl
  class ParseNode
    attr :name
    attr :children

    def self.from_node(node)
      return [node.token.symbol_name, node.token.value] if node.is_a? Dhaka::ParseTreeLeafNode
      return node.production.name, new(node)
    end

    def initialize(node)
      @name = node.production.name
      @children = node.child_nodes.inject({}) do |h, n|
        name, node = ParseNode.from_node n
        h[name] = node
        h
      end
    end

    def inspect
      "#<#{name} #{children.inspect}>"
    end

    def method_missing(name, *args, &block)
      return super(name, *args, &block) unless args.empty? && block.nil?
      sname = name.to_s
      return children[sname[0...-1]] if sname[-1] == ??
      return children[sname] if children[sname]
      super(name)
    end
  end
end
