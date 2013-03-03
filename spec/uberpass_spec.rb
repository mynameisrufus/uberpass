$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$password = File.read(File.join(File.dirname(__FILE__), '..', 'password.txt')).strip
$password.freeze

require 'minitest/spec'
require 'minitest/autorun'
require 'turn/autorun'
require 'uberpass'

describe Uberpass do
  before do
    @input    = StringIO.new
    @output   = StringIO.new

    @input << $password
    @input.rewind

    @uberpass = Uberpass::CLI.new 'test', @input, @output, false

    @input.truncate(@input.rewind)

    Uberpass::FileHandler.generate 'twitter'
    Uberpass::FileHandler.generate 'facebook'
  end

  it "should ask and memorise the password" do
    prompt = "Enter PEM pass phrase: #{$password.gsub(/\w/, '*')}\n"

    assert_equal prompt, @output.string
    assert_equal $password, Uberpass::FileHandler.pass_phrase
  end

  it "should list entries" do
    @output.truncate(@output.rewind)
    @input << 'li'
    @input.rewind

    @uberpass.do_action

    assert_match /facebook/, @output.string
    assert_match /twitter/, @output.string
    assert_match Time.now.strftime("%d/%m/%Y"), @output.string
  end

  it "should raise and catch argument error" do
    @output.truncate(@output.rewind)
    @input << 'wadyawant'
    @input.rewind

    @uberpass.do_action
    assert_match /is not a uberpass command/, @output.string
    assert_match /'wadyawant'/, @output.string
  end
end
