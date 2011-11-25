require 'uberpass/version'
require 'openssl'
require 'yaml'

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

      def show_password(key)
        passwords = decrypted_passwords
        passwords[key]["password"] unless passwords[key].nil?
      end

      def list_keys
        decrypted_passwords.keys
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

      def new_password(key)
        passwords = decrypted_passwords
        passwords[key] = {
          "password" => Array.new(32).map{ rand(2) == 1 ? (65 + rand(58)).chr : rand(10) }.join,
          "created_at" => Time.now
        }
        encryptor = Encrypt.new(File.read(public_key_file), passwords.to_yaml)
        write(encryptor)
        passwords[key]["password"]
      end

      def destroy_password(key)
        passwords = decrypted_passwords
        entry = passwords.delete key
        encryptor = Encrypt.new(File.read(public_key_file), passwords.to_yaml)
        write(encryptor)
        entry
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
    end
  end

  class CLI
    def initialize(namespace)
      FileHandler.configure do |handler|
        handler.namespace = namespace
      end
      print "\nactions:\n"
      print "  generate\n"
      print "  destroy\n"
      print "  reveal\n"
      print "  list\n"
      print "  exit\n"
      actions
    end

    def actions
      print "\n> "
      action, argument = $stdin.gets.chomp.split(' ')
      case action
      when "generate", "g"
        if argument.to_s.strip == ""
          print "choose a name ie. generate twitter"
        else
          password = FileHandler.new_password(argument)
          print "password for #{argument}: #{password}\n"
        end
      when "destroy", "d"
        if argument.to_s.strip == ""
          print "choose a name ie. destroy twitter"
        else
          print "\nare you sure you? [yn] "
          if $stdin.gets.chomp == "y"
            FileHandler.destroy_password(argument)
            print "password removed\n"
          end
        end
      when "reveal", "r"
        if argument.to_s.strip == ""
          print "choose a name ie. reveal twitter"
        else
          password = FileHandler.show_password(argument)
          print "password for #{argument}: #{password}\n"
        end
      when "list", "l"
        keys = FileHandler.list_keys
        print "\n"
        keys.each do |key|
          print " - #{key}\n"
        end 
      when "exit"
        exit
      else
        print "invalid option"
      end
      actions
    end
  end
end
