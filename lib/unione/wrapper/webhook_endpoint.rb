# frozen_string_literal: true

require 'json'
require 'active_support/notifications'

module UniOne
  module Wrapper
    # Rack endpoint of the webhooks (no CSRF, no session): GET/HEAD -> 200 (URL check of webhook/set),
    # POST -> signature check (401 when wrong), then ActiveSupport::Notifications:
    #   "webhook.unione" - the whole notification: payload[:callback] (WebhookCallback), payload[:data] (Hash)
    #   "event.unione"   - every event: payload[:event], payload[:user] (user/project of the event)
    # Subscribers must be fast: the API waits for 200 OK for 3 seconds only.
    class WebhookEndpoint
      HEADERS = { 'content-type' => 'text/plain' }.freeze

      def call(env)
        return reply(200, 'OK') unless env['REQUEST_METHOD'] == 'POST'

        input = env['rack.input']
        body = input ? input.read.to_s : ''
        input&.rewind if input.respond_to?(:rewind)
        return reply(401, 'Invalid signature') unless WebhookSignature.verify(body, ::UniOne::Wrapper.webhook_key)

        begin
          callback = ::UniOne::Api::Webhook::WebhookApi.parse_callback(body)
          data = JSON.parse(body)
        rescue JSON::ParserError, TypeError, NoMethodError
          return reply(400, 'Invalid body')
        end

        ActiveSupport::Notifications.instrument('webhook.unione', callback: callback, data: data)
        (callback.events_by_user || []).each do |user|
          (user.events || []).each do |event|
            ActiveSupport::Notifications.instrument('event.unione', event: event, user: user)
          end
        end
        reply(200, 'OK')
      end

      private

      def reply(status, text)
        [status, HEADERS.dup, [text]]
      end
    end
  end
end
