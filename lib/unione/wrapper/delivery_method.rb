# frozen_string_literal: true

module UniOne
  module Wrapper
    # Action Mailer delivery method :unione, sends through email/send:
    #
    #   config.action_mailer.delivery_method = :unione
    #   config.action_mailer.unione_settings = { api_key: '...' } # optional, default: config.unione
    #
    # The API response ("job_id", "emails", "failed_emails") is in mail.delivery_method.response.
    class DeliveryMethod
      attr_accessor :settings
      attr_reader :response

      def initialize(settings = {})
        @settings = settings || {}
        @response = nil
      end

      def deliver!(mail)
        @response = client.api_client.call('/email/send.json', { 'message' => EmailPayload.from_mail(mail) })
      end

      private

      def client
        return ::UniOne::Wrapper.client if @settings[:api_key].nil?

        ::UniOne::Wrapper.build_client(@settings)
      end
    end
  end
end
