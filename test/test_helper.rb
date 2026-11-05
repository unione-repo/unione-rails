# frozen_string_literal: true

# Tests of the gem: a Rails app in the process; the HTTP layer of the SDK client is FakeTransport (no network, no real
# API).
#
#   bundle install
#   ruby -Ilib -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |f| require File.expand_path(f) }'
ENV['UNIONE_API_KEY'] = 'test-key'
# never reached: the requests go to FakeTransport
ENV['UNIONE_HOST'] = 'http://127.0.0.1:9/api/v1'
%w[WEBHOOK_KEY WEBHOOK_PATH WEBHOOK_ENABLED TIMEOUT].each { |name| ENV.delete("UNIONE_#{name}") }
ENV['RAILS_ENV'] ||= 'test'

require 'bundler/setup'
require 'minitest/autorun'
require 'json'
require 'logger'
require 'rails'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'unione-rails'

class TestApp < Rails::Application
  config.root = __dir__
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = 'x' * 64
  config.hosts.clear
  config.action_mailer.delivery_method = :unione
end
TestApp.initialize!

class TestMailer < ActionMailer::Base
  default from: '"Shop" <shop@example.com>'

  def welcome
    headers['X-Order'] = '42'
    attachments['a.txt'] = { mime_type: 'text/plain', content: 'abc' }
    mail(to: '"User" <user@example.com>', cc: 'cc@example.com', bcc: 'bcc@example.com',
         reply_to: 'support@example.com', subject: 'Test') do |format|
      format.text { render plain: 'Hello' }
    end
  end

  def html_only
    mail(to: 'user@example.com', subject: 'Html') do |format|
      format.html { render html: '<p>Hi</p>'.html_safe }
    end
  end
end

# HTTP layer of the SDK client in the tests: records every request and answers [status, body].
class FakeTransport
  attr_reader :requests

  def initialize(status = 200, body = '{"status":"success","job_id":"test-job"}')
    @status = status
    @body = body
    @requests = []
  end

  def call(method, uri, headers, body, timeout)
    @requests << { method: method, uri: uri, headers: headers, body: body, timeout: timeout }
    [@status, @body]
  end
end

module TestSupport
  ApiError = ::UniOne::Client::ApiError

  # The memoized client of the gem (the one the delivery method uses) on a new FakeTransport.
  def fake_transport(status = 200, body = '{"status":"success","job_id":"test-job"}')
    transport = FakeTransport.new(status, body)
    ::UniOne::Wrapper.client.api_client.instance_variable_set(:@transport, transport)
    transport
  end
end
