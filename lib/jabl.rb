dir = File.dirname(__FILE__)
$LOAD_PATH << dir unless $LOAD_PATH.include?(dir)

require 'jabl/engine'

puts Jabl::Engine.new($stdin.read).render if $0 == __FILE__
