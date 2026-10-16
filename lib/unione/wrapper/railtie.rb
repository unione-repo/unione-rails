# frozen_string_literal: true

require 'rails/railtie'

module UniOne
  module Wrapper
    # config.unione settings, the :unione delivery method of Action Mailer and the webhook route.
    class Railtie < ::Rails::Railtie
      config.unione = ::UniOne::Wrapper.default_configuration

      initializer 'unione.configure' do |app|
        options = app.config.unione
        if options.api_key.nil? || options.api_key.to_s.empty?
          credentials = begin
            app.credentials.unione
          rescue StandardError
            nil
          end
          options.api_key = credentials[:api_key] if credentials.respond_to?(:[])
        end
        ::UniOne::Wrapper.configuration = options
      end

      initializer 'unione.action_mailer' do
        ActiveSupport.on_load(:action_mailer) do
          add_delivery_method :unione, ::UniOne::Wrapper::DeliveryMethod
        end
      end

      initializer 'unione.webhook_route' do |app|
        options = app.config.unione
        if options.webhook_enabled != false
          app.routes.prepend do
            match options.webhook_path, to: ::UniOne::Wrapper::WebhookEndpoint.new, via: %i[get head post],
                                        as: 'unione_webhook'
          end
        end
      end
    end
  end
end
