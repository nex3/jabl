require 'dhaka'

class Jabl
  class NestGrammar < Dhaka::Grammar
    for_symbol Dhaka::START_SYMBOL_NAME do
      fun_statement %w[fun identifier arglist]
    end

    for_symbol 'arglist' do
      empty_args []
      no_args %w[ ( ) ]
      args  %w[ ( args ) ]
    end

    for_symbol 'args' do
      single_arg    %w[ identifier ]
      multiple_args %w[ identifier , arglist_list ]
    end
  end
  NestParser = Dhaka::Parser.new(NestGrammar)
end
