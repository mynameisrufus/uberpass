require 'uberpass/version'
require 'openssl'
require 'yaml'
require 'ostruct'
require 'securerandom'

module Uberpass
  class Decrypt
    attr_reader :decrypted_data

    def initialize(private_key, encrypted_data, encrypted_key, encrypted_iv)
      key = OpenSSL::PKey::RSA.new(private_key)
      cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
      cipher.decrypt
      cipher.key = key.private_decrypt(encrypted_key)
      cipher.iv = key.private_decrypt(encrypted_iv)

      @decrypted_data = cipher.update(encrypted_data)
      @decrypted_data << cipher.final
    end
  end

  class Encrypt
    attr_reader :encrypted_data, :encrypted_key, :encrypted_iv

    def initialize(public_key, decrypted_data)
      key = OpenSSL::PKey::RSA.new(public_key)
      cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
      cipher.encrypt
      cipher.key = random_key = cipher.random_key
      cipher.iv = random_iv = cipher.random_iv

      @encrypted_data = cipher.update(decrypted_data)
      @encrypted_data << cipher.final

      @encrypted_key =  key.public_encrypt(random_key)
      @encrypted_iv = key.public_encrypt(random_iv)
    end
  end
 
  class FileHandler
    class << self
      attr_accessor :namespace
       
      def configure
        yield self
      end
      
      def name_spaced_file(file_name)
        @namespace.nil? ? file_name : "#{file_name}_#{@namespace}"
      end

      def private_key_file
        File.expand_path("~/.uberpass/private.pem")
      end

      def public_key_file
        File.expand_path("~/.uberpass/public.pem")
      end

      def passwords_file
        File.expand_path("~/.uberpass/#{name_spaced_file("passwords")}")
      end

      def key_file
        File.expand_path("~/.uberpass/#{name_spaced_file("key")}")
      end
      
      def iv_file
        File.expand_path("~/.uberpass/#{name_spaced_file("iv")}")
      end

      def write(encryptor)
        File.open(passwords_file, "w") { |file|
          file.write(encryptor.encrypted_data)
        }
        File.open(key_file, "w") { |file|
          file.write(encryptor.encrypted_key)
        }
        File.open(iv_file, "w") { |file|
          file.write(encryptor.encrypted_iv)
        }
      end

      def decrypted_passwords
        if File.exists?(passwords_file)
          YAML::load(
            Decrypt.new(
              File.read(private_key_file),
              File.read(passwords_file),
              File.read(key_file),
              File.read(iv_file)
            ).decrypted_data
          )
        else
          {}
        end
      end

      def show(key)
        Hash[*[key, decrypted_passwords[key]]]
      end

      def all
        decrypted_passwords.map do |entry|
          Hash[*entry]
        end
      end

      def generate_short(key)
        encrypt key, SecureRandom.urlsafe_base64(8)
      end

      def generate(key)
        encrypt key, SecureRandom.urlsafe_base64(24)
      end

      def encrypt(key, password)
        passwords = decrypted_passwords
        entry = passwords[key] = {
          "password" => password,
          "created_at" => Time.now
        }
        encryptor = Encrypt.new(File.read(public_key_file), passwords.to_yaml)
        write(encryptor)
        Hash[*[key, entry]]
      end

      def rename(old, new)
        passwords = decrypted_passwords
        entry = passwords.delete old
        passwords[new] = entry
        encryptor = Encrypt.new(File.read(public_key_file), passwords.to_yaml)
        write(encryptor)
        Hash[*[new, entry]]
      end

      def destroy(key)
        passwords = decrypted_passwords
        entry = passwords.delete key
        encryptor = Encrypt.new(File.read(public_key_file), passwords.to_yaml)
        write(encryptor)
        Hash[*[key, entry]]
      end
        
    end
  end

  class CLI
    class InvalidActionError < StandardError; end
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
      FileHandler.show key
    end

    register_action :encrypt, :steps => ["key", "password"] do |key, password|
      FileHandler.encrypt key, password
    end

    register_action :rename, :steps => ["key", "new name"] do |old, new|
      FileHandler.rename old, new
    end

    register_action :list, :filter => ["password"] do
      FileHandler.all
    end

    register_action :dump do
      FileHandler.all
    end

    register_action :help do
      CLI.help
      []
    end

    register_action :exit, :short => :ex do
      exit
    end

    def initialize(namespace)
      FileHandler.configure do |handler|
        handler.namespace = namespace
      end
      line
      do_action
    end

    def line(message = nil, format = :bold)
      parts = []
      parts << "\nuberpass"
      parts << "#{VERSION}:"
      parts << send(format, message) unless message.nil?
      parts << "> "
      print parts.join(' ')
    end

    def self.help
      print "\nactions:\n"
      actions.each do |action|
        print "  #{action.name}\n"
      end
    end

    def confirm_action
      line "are you sure you? [yn]", :green
      $stdin.gets.chomp == "y"
    end

    def do_action
      input = $stdin.gets.chomp
      do_action_with_rescue input
    end

    def do_action_with_rescue(input)
      args = input.split(/ /)
      begin
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
        print "\n"
        line
        do_action
      rescue MissingArgumentError => e
        line e, :red
        do_action
      rescue InvalidActionError => e
        line e, :red
        do_action
      rescue OpenSSL::PKey::RSAError => e
        line e, :red
        do_action
      end
    end

    def fetch_action(key)
      self.class.actions.each do |action|
        return action if action.name == key.to_sym || action.short == key
      end
      raise InvalidActionError, key
    end

    def pp(entry, filter)
      if entry.is_a? Array
        entry.each do |entry|
          pp entry, filter
        end
      else
        key = entry.keys.first
        filter.each do |f|
          entry[key].delete f
        end
        print "\n#{gray entry[key]["created_at"].strftime("%d/%m/%Y")} #{bold key} "
        print "\n#{entry[key]["password"]}" unless entry[key]["password"].nil?
      end
    end
  end
end
