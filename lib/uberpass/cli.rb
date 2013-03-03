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
      class Register
        attr_accessor :name, :short, :usage, :description, :confirm
        attr_writer :proc

        def call *args
          @proc.call *args
        end
      end

      attr_accessor :actions

      def register_action
        register = Register.new
        yield register
        (@actions ||= []) << register
      end
    end

    HighLine.color_scheme = HighLine::ColorScheme.new do |cs|
      cs[:error]   = [:bold, :red]
      cs[:confirm] = [:green]
      cs[:date]    = [:white]
      cs[:name]    = [:bold]
      cs[:index]   = [:magenta]
    end

    extend Actions

    register_action do |action|
      action.name        = 'help'
      action.short       = 'help'
      action.usage       = 'help'
      action.proc        = ->(terminal) {
        HelpDecorator.new(terminal, self.actions).output
      }
      action.description = "Lists all commands"
    end

    register_action do |action|
      action.name        = 'generate'
      action.short       = 'g'
      action.usage       = 'g google'
      action.proc        = ->(terminal, key) {
        ShowDecorator.new(terminal, FileHandler.generate(key)).output
      }
      action.description = "Generates a random password for a given key"
    end

    register_action do |action|
      action.name        = 'generate_short'
      action.short       = 'gs'
      action.usage       = 'gs [name]'
      action.proc        = ->(terminal, key) {
        ShowDecorator.new(terminal, FileHandler.generate_short(key)).output
      }
      action.description = "Generates a random password but smaller so its easier to type into a phone or a legacy system"
    end

    register_action do |action|
      action.name        = 'destory'
      action.short       = 'rm'
      action.usage       = 'rm [name]'
      action.confirm     = true
      action.proc        = ->(terminal, key) {
        ShowDecorator.new(terminal, FileHandler.destroy(key)).output
      }
      action.description = "Removes and entry"
    end

    register_action do |action|
      action.name        = 'show'
      action.short       = 's'
      action.usage       = 's [name|index]'
      action.proc        = ->(terminal, key) {
        entry = if key =~ /^\d+$/
          FileHandler.all[key.to_i]
        else
          FileHandler.show key
        end
        ShowDecorator.new(terminal, entry).output
      }
      action.description = "Shows an entry"
    end

    register_action do |action|
      action.name        = 'encrypt'
      action.short       = 'e'
      action.usage       = '[name] << [password]'
      action.proc        = ->(terminal, key, password) {
        ShowDecorator.new(terminal, FileHandler.encrypt(key, password)).output
      }
      action.description = "Encrypts a value"
    end

    register_action do |action|
      action.name        = 'rename'
      action.short       = 'mv'
      action.usage       = 'mv [name] [new name]'
      action.proc        = ->(terminal, old, new) {
        ShowDecorator.new(terminal, FileHandler.rename(old, new)).output
      }
      action.description = "Rename an entry"
    end

    register_action do |action|
      action.name        = 'list'
      action.short       = 'ls'
      action.usage       = 'ls'
      action.proc        = ->(terminal) {
        ListDecorator.new(terminal, FileHandler.all).output
      }
      action.description = "Lists all entries"
    end

    register_action do |action|
      action.name        = 'dump'
      action.short       = 'dump'
      action.usage       = 'dump'
      action.proc        = ->(terminal) {
        DumpDecorator.new(terminal, FileHandler.all).output
      }
      action.description = "Dumps all entries including passwords"
    end

    def initialize(namespace, input = $stdin, output = $stdout, run_loop = true)
      @input    = input
      @output   = output
      @run_loop = run_loop
      @terminal = HighLine.new @input, @output

      pass = @terminal.ask("Enter PEM pass phrase: ") { |q| q.echo = '*' }
      @output.print "\n"

      FileHandler.configure do |handler|
        handler.namespace = namespace
        handler.pass_phrase = pass
      end
      do_action if @run_loop
    end

    def self.help
      print "\nactions:\n"
      actions.each do |action|
        @output.print "  #{action.name}\n"
      end
    end

    def confirm_action
      @terminal.agree("<%= color('are you sure?', :confirm) %> ") { |q| q.default = "n" }
    end

    def do_action
      input = @terminal.ask "uberpass:#{VERSION}> "
      return if input.strip == 'exit'
      @output.print "\n\n"
      do_action_with_rescue input
      @output.print "\n"
      do_action if @run_loop
    end

    def do_action_with_rescue(input)
      args = input.split(/ /).compact
      if args[1] == '<'
        action = fetch_action 'encrypt'
        args.slice!(1)
      else
        action = fetch_action args.slice!(0)
      end

      if action.confirm && @run_loop
        action.call(@terminal, *args) if confirm_action
      else
        action.call(@terminal, *args)
      end
    rescue MissingArgumentError, InvalidActionError, OpenSSL::PKey::RSAError => e
      @terminal.say "<%= color('#{e}', :error) %>"
    rescue FileHandler::ExistingEntryError => key
      @terminal.say "<%= color('#{key} is already defined, try deleting it first', :error) %>"
    end

    def fetch_action(key)
      self.class.actions.each do |action|
        return action if action.name == key || action.short == key
      end
      raise InvalidActionError, key
    end

    class ListDecorator
      def initialize terminal, entries
        @terminal, @entries = terminal, entries
      end

      def output
        @entries.each_with_index do |entry, index|
          key = entry.keys.first
          output_entry key, entry[key], index
        end
      end

      def output_entry(key, values, index)
        out = "<%= color('#{values["created_at"].strftime("%d/%m/%Y")}', :date) %>"
        out << " <%= color('[#{index}]', :index) %>"
        out << " <%= color('#{key}', :name) %>"
        @terminal.say out
      end
    end

    class DumpDecorator < ListDecorator
      def initialize terminal, entries
        @terminal, @entries = terminal, entries
      end

      def output
        @entries.each do |entry|
          key = entry.keys.first
          output_entry key, entry[key]
        end
      end

      def output_entry(key, value)
        out = "<%= color('#{key}', :name) %>"
        out << " #{value["password"]}"
        @terminal.say out
      end
    end

    class ShowDecorator
      def initialize terminal, entry
        @terminal, @entry = terminal, entry
      end

      def output
        key = @entry.keys.first
        output_entry key, @entry[key]
      end

      def output_entry(key, values)
        out = "<%= color('#{values["created_at"].strftime("%d/%m/%Y")}', :date) %>"
        out << " <%= color('#{key}', :name) %>\n"
        out << "<%= color('#{values["password"]}', :name) %>"

        @terminal.say out
      end
    end

    class HelpDecorator
      def initialize terminal, actions
        @terminal, @actions = terminal, actions
      end

      def output
        @actions.each do |action|
          next if action.name == 'help'
          @terminal.say <<HELP
<%= color('#{action.name} -  #{action.description}', BOLD) %> 
usage: #{action.usage}

HELP
        end
      end
    end
  end
end
