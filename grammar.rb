require 'dhaka'

class Jabl
  class NestGrammar < Dhaka::Grammar
    for_symbol Dhaka::START_SYMBOL_NAME do
      fun_statement ['fun_statement']
    end

    for_symbol 'fun_statement' do
      argless %w[fun identifier]
    end
  end
  NestParser = Dhaka::Parser.new(NestGrammar)
end
