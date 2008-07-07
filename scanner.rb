require 'strscan'

class Jabl
  class Scanner < StringScanner
    def keyword(str)
      scan(/\b#{Regexp.escape(str.to_s)}\b/)
    end

    def whitespace
      scan(/\s+/)
    end

    def whitespace?
      scan(/\s*/)
    end

    def identifier
      scan(/\w+/)
    end

    def eos!
      return if eos?
      raise "Expected end of line, got #{rest.inspect}"
    end

    def method_missing(name, *args, &block)
      super(name, *args, &block) unless name.to_s[-1] == ?!
      name = name.to_s
      res = send(name[0...-1], *args, &block)
      return res if res
      raise "Expected #{name[0...-1]}(#{args.inspect[1...-1]})"
    end
  end
end
