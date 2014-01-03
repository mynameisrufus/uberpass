require 'securerandom'

module Uberpass
  class FileHandler
    class ExistingEntryError < StandardError; end

    class << self
      attr_accessor :namespace, :pass_phrase

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
        File.open(passwords_file, "w+") { |file|
          file.write(encryptor.encrypted_data)
        }
        File.open(key_file, "w+") { |file|
          file.write(encryptor.encrypted_key)
        }
        File.open(iv_file, "w+") { |file|
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
              File.read(iv_file),
              pass_phrase
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
        raise ExistingEntryError, key unless passwords[key].nil?
        entry = passwords[key] = {
          "password" => password,
          "created_at" => Time.now
        }
        encryptor = Encrypt.new(File.read(public_key_file), passwords.to_yaml, pass_phrase)
        write(encryptor)
        Hash[*[key, entry]]
      end

      def rename(old, new)
        passwords = decrypted_passwords
        raise ExistingEntryError, new unless passwords[new].nil?
        entry = passwords.delete old
        passwords[new] = entry
        encryptor = Encrypt.new(File.read(public_key_file), passwords.to_yaml)
        write(encryptor)
        Hash[*[new, entry]]
      end

      def remove(key)
        passwords = decrypted_passwords
        entry = passwords.delete key
        encryptor = Encrypt.new(File.read(public_key_file), passwords.to_yaml)
        write(encryptor)
        Hash[*[key, entry]]
      end
    end
  end
end
