$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$password = File.read(File.join(File.dirname(__FILE__), '..', 'password.txt')).strip
$password.freeze

require 'uberpass'

input  = StringIO.new
output = StringIO.new

input << $password
input.rewind

uberpass = Uberpass::CLI.new 'test', input, output, false

input.truncate input.rewind

puts output.string
output.truncate output.rewind

input << 'ls'
input.rewind
uberpass.do_action
input.truncate input.rewind

puts output.string
output.truncate output.rewind

input << 'dump'
input.rewind
uberpass.do_action
input.truncate input.rewind

puts output.string
output.truncate output.rewind

input << 'g cia'
input.rewind
uberpass.do_action
input.truncate input.rewind

puts output.string
output.truncate output.rewind

input << 'cat cia'
input.rewind
uberpass.do_action
input.truncate input.rewind

puts output.string
output.truncate output.rewind

input << 'help'
input.rewind
uberpass.do_action
input.truncate input.rewind

puts output.string
output.truncate output.rewind
