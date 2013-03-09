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

    Uberpass::FileHandler.all.each do |entry|
      Uberpass::FileHandler.remove entry.keys.first
    end

    Uberpass::FileHandler.generate 'twitter'
    Uberpass::FileHandler.generate 'facebook'
  end

  it "should ask and memorise the password" do
    prompt = "Enter PEM pass phrase: #{$password.gsub(/\w/, '*')}\n\n"

    assert_equal prompt, @output.string
    assert_equal $password, Uberpass::FileHandler.pass_phrase
  end

  it "should list entries" do
    @output.truncate(@output.rewind)
    @input << 'ls'
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

  it "should confirm deletion of password" do
    Uberpass::FileHandler.generate 'linkedin'

    @output.truncate(@output.rewind)
    @input << 'rm linkedin'
    @input.rewind

    @uberpass.do_action

    @input.truncate(@input.rewind)
    @input << 'yes'
    @input.rewind

    @uberpass.confirm_action

    assert_match /are you sure\?/, @output.string
    assert_match /linkedin/, @output.string
    assert_match Time.now.strftime("%d/%m/%Y"), @output.string
  end

  it "should encrypt an existing password with <" do
    @output.truncate(@output.rewind)
    @input << 'google < xxx'
    @input.rewind

    @uberpass.do_action

    password = Uberpass::FileHandler.show 'google'

    refute_nil password['google']['password']
  end

  it "should encrypt an existing password with <" do
    @output.truncate(@output.rewind)
    @input << 'e foursquare xxx'
    @input.rewind

    @uberpass.do_action

    password = Uberpass::FileHandler.show 'foursquare'

    refute_nil password['foursquare']['password']
  end

  it "should rename a key" do
    Uberpass::FileHandler.generate 'tumbler'

    @output.truncate(@output.rewind)
    @input << 'mv tumbler tumblr'
    @input.rewind

    @uberpass.do_action

    password = Uberpass::FileHandler.show 'tumbler'
    assert_nil password['tumbler']

    password = Uberpass::FileHandler.show 'tumblr'
    refute_nil password['tumblr']
  end

  it "should show an error if key missing" do
    @output.truncate(@output.rewind)
    @input << 's missing'
    @input.rewind

    @uberpass.do_action

    assert_match /missing does not exist/, @output.string
  end
end
