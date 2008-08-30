dir = File.dirname(__FILE__)
$LOAD_PATH << dir unless $LOAD_PATH.include?(dir)

rkelly_dir = File.join(File.dirname(__FILE__), '..', 'vendor', 'jabl-rkelly', 'lib')
$LOAD_PATH << rkelly_dir unless $LOAD_PATH.include?(rkelly_dir)

require 'jabl/engine'

puts Jabl::Engine.new($stdin.read).render if $0 == __FILE__
