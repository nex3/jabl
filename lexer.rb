require 'dhaka'

class Jabl
  class NestLexerSpec < Dhaka::LexerSpecification
    KEYWORDS = %w[fun]
    PUNCTUATION = %w[, ( )]

    (KEYWORDS + PUNCTUATION).each {|k| for_symbol(k) {create_token(k)}}

    for_pattern('\w+') {create_token 'identifier'}

    for_pattern(' ') {}
  end
  NestLexer = Dhaka::Lexer.new(NestLexerSpec)
end
