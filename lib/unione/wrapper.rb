# frozen_string_literal: true

require 'unione'
require 'active_support'
require 'active_support/ordered_options'
require_relative 'wrapper/version'
require_relative 'wrapper/webhook_signature'
require_relative 'wrapper/email_payload'
require_relative 'wrapper/delivery_method'
require_relative 'wrapper/webhook_endpoint'

module UniOne
  # Rails integration: UniOne::Wrapper.client is the UniOne API client configured by config.unione.
  module Wrapper
    class << self
      # Settings: api_key, host, timeout, webhook_key, webhook_path, webhook_enabled (config.unione in Rails).
      def configuration
        @configuration ||= default_configuration
      end

      def configuration=(options)
        @configuration = options
        @client = nil
      end

      def configure
        yield configuration
        @client = nil
      end

      # @return [UniOne::UniOneClient] memoized client of the configuration
      def client
        @client ||= build_client(configuration)
      end

      # A client for other settings: { api_key:, host:, timeout: } (missing ones come from the configuration).
      def build_client(options)
        api_key = present(options[:api_key])
        raise ArgumentError, 'UniOne: set config.unione.api_key (UNIONE_API_KEY)' if api_key.nil?

        timeout = present(options[:timeout]) || configuration[:timeout] || 30
        ::UniOne::UniOneClient.new(api_key, present(options[:host]), timeout: timeout.to_i, platform: PLATFORM)
      end

      # API key the webhook notifications are signed with.
      def webhook_key
        present(configuration[:webhook_key]) || present(configuration[:api_key]).to_s
      end

      def default_configuration
        options = ActiveSupport::OrderedOptions.new
        options.api_key = ENV['UNIONE_API_KEY']
        options.host = ENV['UNIONE_HOST']
        options.timeout = (ENV['UNIONE_TIMEOUT'] || 30).to_i
        options.webhook_key = ENV['UNIONE_WEBHOOK_KEY']
        options.webhook_path = ENV['UNIONE_WEBHOOK_PATH'] || '/unione/webhook'
        options.webhook_enabled = ENV['UNIONE_WEBHOOK_ENABLED'] != 'false'
        options
      end

      private

      def present(value)
        value.nil? || value.to_s.empty? ? nil : value
      end
    end
  end
end

require_relative 'wrapper/railtie' if defined?(::Rails::Railtie)
