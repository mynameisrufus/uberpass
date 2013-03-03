require 'openssl'

module Uberpass
  class Encrypt
    attr_reader :encrypted_data, :encrypted_key, :encrypted_iv

    def initialize(public_key, decrypted_data, pass_phrase = nil)
      key = OpenSSL::PKey::RSA.new(public_key, pass_phrase)
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
end
