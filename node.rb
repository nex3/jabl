require 'scanner'

class Jabl
  class Node < Struct.new(
      :text, :index, :children, :scanner, :parsed, :data, :name)

    attr_writer :getter
    attr_writer :peek_next

    def initialize(*args)
      super
      self.data ||= {}
      self.scanner ||= Scanner.new(text)
    end

    def parse!
      raise "Jabl bug: parsing parsed node" if parsed?
      DIRECT_BLOCK_STATEMENTS.each do |name|
        if scanner.keyword name
          parse_block(name)
          return
        end
      end

      if scanner.keyword :fun; parse_fun
      elsif scanner.keyword :if; parse_if
      elsif scanner.keyword :do; parse_do_while
      elsif scanner.keyword :try; parse_try
      elsif scanner.keyword :let; parse_let
      elsif scanner.scan /%/; parse_selector
      elsif scanner.scan /\:/; parse_event
      elsif scanner.scan /\./; parse_scoped
      elsif scanner.keyword :switch; parse_switch
      else parse_text
      end
    end

    def compiled?
      compiled
    end

    def parsed?
      parsed
    end

    def [](name)
      data[name]
    end

    def []=(name, val)
      data[name] = val
    end

    def context_refs
      @context_refs ||=
        begin
          children.inject(0) {|s, c| s + c.context_refs} +
            context_refs_in(self[:expr]) +
            case name
            when :event; 1
            when :scoped; 1 + context_refs_in(self[:text])
            when :text; context_refs_in(self[:text])
            else; 0
            end
        end
    end

    def get!
      self.parsed = true
      @getter.call
    end

    protected

    def peek_next
      @next ||= @peek_next.call
    end

    def context_refs_in(text)
      (text || "").count('@')
    end

    def parse_scoped
      self.name = :scoped
      self[:text] = scanner.scan!(/.+/)
    end

    def parse_switch
      self.name = :switch
      scanner.whitespace!
      self[:expr] = scanner.scan!(/.+/)

      self[:cases] = []
      node = self
      while node = node.peek_next
        if node.scanner.keyword(:case)
          node.get!
          node.scanner.whitespace!
          node.name = :case
          node[:expr] = node.scanner.scan!(/.+/)
          self[:cases] << node
        elsif node.scanner.keyword(:default)
          node.get!
          node.name = :default
          self[:cases] << node
        else
          break
        end
      end
    end

    def parse_text
      self.name = :text
      self[:text] = self.text
    end

    def parse_block(name = nil)
      self.name = name.to_sym if name

      scanner.whitespace!
      self[:expr] = scanner.scan!(/.+/)
    end

    def parse_fun
      self.name = :fun

      scanner.whitespace!
      self[:name] = scanner.identifier!
      self[:args] = []
      if scanner.scan(/\(/)
        loop do
          scanner.whitespace
          self[:args] << scanner.identifier!
          scanner.whitespace
          unless scanner.scan(/,/)
            scanner.scan!(/\)/)
            break
          end
        end
      end
    end

    def parse_if
      parse_block 'if'

      self[:else] = []
      node = self
      while node.peek_next && node.peek_next.scanner.keyword(:else)
        node = node.peek_next
        node.get!
        self[:else] << node
        node.parse_else
      end
    end

    def parse_else
      self.name = :else
      return unless scanner.whitespace

      scanner.keyword! 'if'
      parse_block
    end

    def parse_do_while
      self.name = :do_while
      self.peek_next.scanner.keyword! 'while'
      self.peek_next.scanner.whitespace!
      self[:expr] = self.peek_next.scanner.scan!(/.+/)
      self.peek_next.get!
    end

    def parse_try
      self.name = :try
      scanner.eos!

      node = self
      if node.peek_next && node.peek_next.scanner.keyword(:catch)
        node = node.peek_next
        node.parse_block 'catch'
        node.get!
        self[:catch] = node
      end

      if node.peek_next && node.peek_next.scanner.keyword(:finally)
        node = node.peek_next
        node.name = :finally
        node.get!
        self[:finally] = node
      end
    end

    def parse_let
      self.name = :let
      scanner.whitespace!

      self[:terms] = []
      loop do
        term = []
        scanner.whitespace
        term << scanner.identifier!
        scanner.whitespace
        scanner.scan!(/=/) # Emacs fix: /)
        scanner.whitespace
        term << scanner.scan!(/[^,]+/) # TODO: Actually parse expression
        self[:terms] << term
        unless scanner.scan(/,/)
          scanner.eos!
          break
        end
      end
    end

    def parse_selector
      self.name = :selector
      self[:text] = scanner.scan!(/.+/)
    end

    def parse_event
      self.name = :event
      self[:name] = scanner.identifier!

      if scanner.scan(/\(/)
        scanner.whitespace
        self[:var] = scanner.identifier
        scanner.whitespace
        scanner.scan!(/\)/)
      end
      scanner.eos!
    end
  end
end
