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
      # "no such route": the router goes on to the next routes (a route of the app on the same path, else 404);
      # the router of Rails 6.1 / 7.0 reads "X-Cascade", of 7.1+ (Rack 3) "x-cascade"
      NOT_FOUND = [404, { 'X-Cascade' => 'pass', 'x-cascade' => 'pass' }.freeze, [].freeze].freeze

      def call(env)
        # turned off after the routes were drawn (webhook_enabled = false): as if the route was not there
        return NOT_FOUND if ::UniOne::Wrapper.configuration.webhook_enabled == false
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
