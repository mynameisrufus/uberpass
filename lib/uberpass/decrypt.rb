require 'openssl'

module Uberpass
  class Decrypt
    attr_reader :decrypted_data

    def initialize(private_key, encrypted_data, encrypted_key, encrypted_iv, pass_phrase = nil)
      key = OpenSSL::PKey::RSA.new(private_key, pass_phrase)
      cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
      cipher.decrypt
      cipher.key = key.private_decrypt(encrypted_key)
      cipher.iv = key.private_decrypt(encrypted_iv)
      @decrypted_data = cipher.update(encrypted_data)
      @decrypted_data << cipher.final
    end
  end
end
