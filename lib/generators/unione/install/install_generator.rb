# frozen_string_literal: true

require 'rails/generators'

module UniOne
  module Wrapper
    module Generators
      # rails generate unione:install - the delivery method :unione of Action Mailer in
      # config/environments/production.rb and config/initializers/unione.rb (the settings, a webhook subscriber).
      # Runs again safely.
      class InstallGenerator < ::Rails::Generators::Base
        namespace 'unione:install'
        desc 'Send the Action Mailer mail through UniOne and create config/initializers/unione.rb'

        INITIALIZER = <<~'RUBY'
          # frozen_string_literal: true

          # UniOne API (gem unione-rails). The settings default to the environment: UNIONE_API_KEY, UNIONE_HOST, UNIONE_TIMEOUT,
          # UNIONE_WEBHOOK_KEY, UNIONE_WEBHOOK_PATH; the API key also to the credentials (unione: { api_key: ... }).
          UniOne::Wrapper.configure do |config|
            # config.api_key = ENV.fetch('UNIONE_API_KEY')
            # config.host = 'api.unione.io'
          end

          # Webhooks at /unione/webhook (register the URL with webhook/set): every event of a notification.
          # Answer fast: the API waits for 200 OK for 3 seconds, process the events in a background job.
          ActiveSupport::Notifications.subscribe('event.unione') do |*, payload|
            event = payload[:event]
            Rails.logger.info("UniOne #{event.event_name}: #{event.event_data&.email}")
          end
        RUBY

        # Production only: development and test keep their delivery method (no real mail from them).
        def delivery_method
          line = 'config.action_mailer.delivery_method = :unione'
          path = File.join(destination_root, 'config/environments/production.rb')
          text = File.exist?(path) ? File.read(path) : nil
          return if text&.include?(line)

          if text.nil? || text.match?(/^\s*config\.action_mailer\.delivery_method\s*=/)
            say "Add to config/environments/production.rb (or the environment that sends mail): #{line}", :yellow
          else
            environment line, env: 'production'
          end
        end

        def initializer
          create_file 'config/initializers/unione.rb', INITIALIZER, skip: true
        end

        def next_steps
          say 'Set UNIONE_API_KEY in the environment (or unione: { api_key: ... } in the credentials).'
        end
      end
    end
  end
end
