require 'classmate/rails/controller/url_rewriting'
require 'classmate/rails/controller/redirects'

module Classmate
  module Rails

    # Rails application controller extension
    module Controller
      def self.included(base)
        base.class_eval do
          include Classmate::Rails::Controller::UrlRewriting
          include Classmate::Rails::Controller::Redirects

          # Fix cookie permission issue in IE
          # before_action :normal_cookies_for_ie_in_iframes!

          helper_method(:classmate, :classmate_params, :cm_signed_params, :current_classmate_user,
            :params_without_classmate_data, :init_js_params, :cm_canvas?
          )

          helper Classmate::Rails::Helpers
        end
      end

      protected

      CLASSMATE_PARAM_NAMES = %w{logged_user_id api_server application_key session_key session_secret_key authorized apiconnection refplace referer
        auth_sig sig custom_args ip_geo_location new_sig payment_promo_active}
      DEBUG_PARAMS = %w{first_start clientLog web_server}
      RAILS_PARAMS = %w{controller action}

      # Accessor to current application config. Override it in your controller
      # if you need multi-application support or per-request configuration selection.
      def classmate
        Classmate::Config.default
      end

      # Accessor to current odnoklassniki user. Returns instance of Classmate::User
      def current_classmate_user
        @current_classmate_user ||= fetch_current_classmate_user
      end

      # A hash of params passed to this action, excluding secure information passed by Moymir
      def params_without_classmate_data
        params.except(*(CLASSMATE_PARAM_NAMES + DEBUG_PARAMS))
      end

      # params coming directly from Odnoklassniki
      def classmate_params
        params.except(*RAILS_PARAMS)
      end

      # encrypted classmate params
      def cm_signed_params
        if classmate_params['session_key'].present?
          encrypt(classmate_params)
        else
          request.env["HTTP_SIGNED_PARAMS"] || request.params['signed_params'] || flash[:signed_params]
        end
      end

      # FIXME params to initialize JS API - might be better to store in cookies
      def init_js_params
        if classmate_params['session_key'].present?
          classmate_params.slice('api_server', 'apiconnection')
        else
          decrypt(cm_signed_params).try(:slice, 'api_server', 'apiconnection')
        end
      end

      # Did the request come from canvas app
      def cm_canvas?
        classmate_params['session_key'].present? || request.env['HTTP_SIGNED_PARAMS'].present? || flash[:signed_params].present?
      end

      private

        def fetch_current_classmate_user
          Classmate::User.from_classmate_params(classmate, classmate_params['session_key'].present? ? classmate_params : cm_signed_params)
        end

        def encrypt(params)
          encryptor = ActiveSupport::MessageEncryptor.new("secret_key_#{classmate.secret_key}"[0..31]) #should be 32

          encryptor.encrypt_and_sign(params)
        end

        def decrypt(encrypted_params)
          encryptor = ActiveSupport::MessageEncryptor.new("secret_key_#{classmate.secret_key}")

          encryptor.decrypt_and_verify(encrypted_params)
        rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
          nil
        end
    end
  end
end