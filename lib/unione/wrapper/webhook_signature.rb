# frozen_string_literal: true

require 'digest/md5'
require 'active_support/security_utils'

module UniOne
  module Wrapper
    # Signature of the webhook notifications: the "auth" field is the MD5 of the request body in which the "auth"
    # value is replaced by the API key of the user/project of the webhook.
    module WebhookSignature
      PLACEHOLDER = '0' * 32

      def self.verify(body, api_key)
        return false if api_key.nil? || api_key.empty?

        match = body.match(/"auth"\s*:\s*"(\h{32})"/)
        return false if match.nil?

        expected = Digest::MD5.hexdigest(body.gsub(match[1], api_key))
        ActiveSupport::SecurityUtils.secure_compare(match[1].downcase, expected)
      end

      # Signs a body that has "auth" set to the placeholder, e.g. for tests.
      def self.sign(body, api_key, placeholder = PLACEHOLDER)
        body.gsub(placeholder, Digest::MD5.hexdigest(body.gsub(placeholder, api_key)))
      end
    end
  end
end
