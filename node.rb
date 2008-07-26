require 'scanner'

class Jabl
  class Node < Struct.new(
      :text, :index, :children, :next, :prev, :scanner, :parsed, :data, :name)

    def initialize(*args)
      super
      self.data ||= {}
      self.scanner ||= Scanner.new(text)
    end

    def parse!
      return if parsed?
      if children.empty?
        if scanner.scan /\./; parse_scoped
        elsif scanner.keyword :switch; parse_switch
        else parse_text
        end
      else
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
        elsif scanner.scan /\$/; parse_selector
        elsif scanner.scan /\:/; parse_event
        else; raise "Invalid parse node: #{text.inspect}"
        end
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
      while node = node.next
        if node.scanner.keyword(:case)
          node.parsed = true
          node.scanner.whitespace!
          node.name = :case
          node[:expr] = node.scanner.scan!(/.+/)
          self[:cases] << node
        elsif node.scanner.keyword(:default)
          node.parsed = true
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
      while node.next && node.next.scanner.keyword(:else)
        node = node.next
        self[:else] << node
        node.parse_else
        node.parsed = true
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
      self.next.scanner.keyword! 'while'
      self.next.scanner.whitespace!
      self[:expr] = self.next.scanner.scan!(/.+/)
      self.next.parsed = true
    end

    def parse_try
      self.name = :try
      scanner.eos!

      node = self
      if node.next && node.next.scanner.keyword(:catch)
        node = node.next
        node.parse_block 'catch'
        node.parsed = true
        self[:catch] = node
      end

      if node.next && node.next.scanner.keyword(:finally)
        node = node.next
        node.name = :finally
        node.parsed = true
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
