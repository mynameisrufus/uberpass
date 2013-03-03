require 'ostruct'
require "highline"

module Uberpass
  class CLI
    class InvalidActionError < StandardError
      attr_reader :action

      def initialize action
        @action = action
        super
      end

      def to_s
        "\\'#{action}\\' is not a uberpass command"
      end
    end

    class MissingArgumentError < StandardError; end

    module Actions
      attr_accessor :actions

      def register_action(*args, &block)
        options           = args.size == 1 ? {} : (args.last || {})
        options[:short]   = options[:short].nil? ? args.first[0] : options.delete(:short).to_s
        options[:steps]   = [] if options[:steps].nil?
        options[:filter] = [] if options[:filter].nil?
        options[:confirm] = false if options[:confirm].nil?
        (@actions ||= []) << OpenStruct.new({ :name => args.first, :proc => block }.merge(options))
      end
    end

    module Formater
      def bold(obj)
        "\033[0;1m#{obj}\033[0m"
      end

      def red(obj)
        "\033[01;31m#{obj}\033[0m"
      end

      def green(obj)
        "\033[0;32m#{obj}\033[0m"
      end
    
      def gray(obj)
        "\033[1;30m#{obj}\033[0m"
      end
    end

    HighLine.color_scheme = HighLine::ColorScheme.new do |cs|
      cs[:error] = [:bold, :red]
    end

    extend Actions
    include Formater

    register_action :generate, :steps => ["key"] do |key|
      FileHandler.generate key
    end

    register_action :generate_short, :steps => ["key"], :short => :gs do |key|
      FileHandler.generate_short key
    end

    register_action :destroy, :steps => ["key"], :short => :rm, :confirm => true do |key|
      FileHandler.destroy key
    end

    register_action :show, :steps => ["key"] do |key|
      if key =~ /^\d+$/
        FileHandler.all[key.to_i]
      else
        FileHandler.show key
      end
    end

    register_action :encrypt, :steps => ["key", "password"] do |key, password|
      FileHandler.encrypt key, password
    end

    register_action :rename, :steps => ["key", "new name"] do |old, new|
      FileHandler.rename old, new
    end

    register_action :list, :short => :li, :filter => ["password"] do
      FileHandler.all
    end

    register_action :dump do
      FileHandler.all
    end

    register_action :help do
      CLI.help
      []
    end

    def initialize(namespace, input = $stdin, output = $stdout, run_loop = true)
      @input    = input
      @output   = output
      @run_loop = run_loop
      @terminal = HighLine.new @input, @output

      pass = @terminal.ask("Enter PEM pass phrase: ") { |q| q.echo = '*' }
      FileHandler.configure do |handler|
        handler.namespace = namespace
        handler.pass_phrase = pass
      end
      do_action if @run_loop
    end

    def line(message = nil, format = :bold)
      parts = []
      parts << "\nuberpass"
      parts << "#{VERSION}:"
      parts << send(format, message) unless message.nil?
      parts << "> "
      @output.print parts.join(' ')
    end

    def self.help
      print "\nactions:\n"
      actions.each do |action|
        @output.print "  #{action.name}\n"
      end
    end

    def confirm_action
      line "are you sure you? [yn]", :green
      $stdin.gets.chomp == "y"
    end

    def do_action
      input = @terminal.ask "uberpass:#{VERSION}> "
      return if input.strip == 'exit'
      do_action_with_rescue input
      do_action if @run_loop
    end

    def do_action_with_rescue(input)
      args = input.split(/ /)
      begin
        raise ArgumentError if args.count == 0
        action = fetch_action args.slice!(0)
        action.steps[args.size, action.steps.size].each do |instruction|
          line instruction, :green
          arg = $stdin.gets.chomp
          raise MissingArgumentError, instruction if arg == ""
          args << arg
        end 
        if action.confirm
          pp(action.proc.call(*args), action.filter) if confirm_action
        else
          pp(action.proc.call(*args), action.filter)
        end
        @output.print "\n"
        line
      rescue MissingArgumentError => e
        @terminal.say "<%= color('#{e}', :error) %>!"
      rescue InvalidActionError => e
        @terminal.say "<%= color('#{e}', :error) %>!"
      rescue OpenSSL::PKey::RSAError => e
        @terminal.say "<%= color('#{e}', :error) %>!"
      end
    end

    def fetch_action(key)
      self.class.actions.each do |action|
        return action if action.name == key.to_sym || action.short == key
      end
      raise InvalidActionError, key
    end

    def pp(entry, filter, index = nil)
      if entry.is_a? Array
        entry.each_with_index do |entry, index|
          pp entry, filter, index
        end
      else
        key = entry.keys.first
        filter.each do |f|
          entry[key].delete f
        end
        @output.print "\n#{gray entry[key]["created_at"].strftime("%d/%m/%Y")} [#{index}] #{bold key} "
        @output.print "\n#{entry[key]["password"]}" unless entry[key]["password"].nil?
      end
    end
  end
end
