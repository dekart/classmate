module Classmate

  # A class for Odnoklassniki user
  class User
    class UnsupportedAlgorithm < StandardError; end
    class InvalidSignature < StandardError; end

    class << self
      # Creates an instance of Classmate::User using application config and request parameters
      def from_classmate_params(config, params)
        params = decrypt(config, params) if params.is_a?(String)

        return unless params && params['logged_user_id'] && signature_valid?(config, params)

        new(params)
      end

      def decrypt(config, encrypted_params)
        key = Digest::MD5.hexdigest("secret_key_#{config.secret_key}")

        encryptor = ActiveSupport::MessageEncryptor.new(key)

        encryptor.decrypt_and_verify(encrypted_params)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
        ::Rails.logger.error "\nError while decoding classmate params: \"#{ encrypted_params }\""

        nil
      end

      def signature_valid?(config, params)
        param_string = params.except('sig').permit!.to_hash.sort.map{|key, value| "#{key}=#{value}"}.join

        params['sig'] == Digest::MD5.hexdigest(param_string + config.secret_key)
      end
    end

    def initialize(options = {})
      @options = options
    end

    # Checks if user is authenticated in the application
    def authenticated?
      !session_key.blank?
    end

    # Odnoklassniki UID
    def uid
      @options['logged_user_id']
    end

    def session_key
      @options['session_key']
    end

    def session_secret_key
      @options['session_secret_key']
    end

    # connection name for JS API
    def apiconnection
      @options['apiconnection']
    end

    # referer data
    def refplace
      @options['refplace']
    end

    def referer
      @options['referer']
    end

    # Odnoklassniki API client instantiated with user's session key
    def api_client
      @api_client ||= Classmate::Api::Client.new(session_key, session_secret_key)
    end
  end
end
