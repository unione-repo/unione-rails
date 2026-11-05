# frozen_string_literal: true

require 'test_helper'

# The client of config.unione and the Action Mailer delivery method :unione.
class ClientTest < Minitest::Test
  include TestSupport

  def test_client_from_the_rails_config
    options = Rails.application.config.unione
    assert_equal 'test-key', options.api_key
    assert_same options, ::UniOne::Wrapper.configuration

    client = ::UniOne::Wrapper.client
    assert_instance_of ::UniOne::UniOneClient, client
    assert_same client, ::UniOne::Wrapper.client
    assert_equal 'test-key', client.api_client.config.api_key
    assert_equal 'http://127.0.0.1:9/api/v1', client.api_client.config.base_url
    assert_equal 30, client.api_client.config.timeout
  end

  def test_requests_carry_the_platform_of_the_gem
    transport = fake_transport(200, '{"status":"success"}')

    ::UniOne::Wrapper.client.system.ping

    sent = transport.requests[0]
    assert_equal '/api/v1/system/ping.json', sent[:uri].path
    assert_equal 'rails.1.3.0', ::UniOne::Wrapper::PLATFORM
    assert_equal [['platform', 'rails.1.3.0,ruby-sdk.1.3.0']], URI.decode_www_form(sent[:uri].query)
    assert_equal 'test-key', sent[:headers]['X-API-KEY']
  end

  def test_build_client
    client = ::UniOne::Wrapper.build_client({ api_key: 'other-key', host: 'eu1.example.com', timeout: 5 })
    config = client.api_client.config
    assert_equal 'other-key', config.api_key
    assert_equal "https://eu1.example.com#{::UniOne::Client::Configuration::BASE_PATH}", config.base_url
    assert_equal 5, config.timeout

    error = assert_raises(ArgumentError) { ::UniOne::Wrapper.build_client({ api_key: '' }) }
    assert_includes error.message, 'UNIONE_API_KEY'
  end

  def test_delivery_method_is_registered
    assert_equal ::UniOne::Wrapper::DeliveryMethod, ActionMailer::Base.delivery_methods[:unione]
  end

  def test_mail_is_sent_through_email_send
    transport = fake_transport

    mail = TestMailer.welcome.deliver_now

    assert_equal 1, transport.requests.size
    sent = transport.requests[0]
    assert_equal '/api/v1/email/send.json', sent[:uri].path
    message = JSON.parse(sent[:body])['message']
    recipients = message['recipients'].map { |r| [r['email'], r['substitutions']] }.to_h
    headers = message['headers'].transform_keys(&:downcase)
    assert_equal 'shop@example.com', message['from_email']
    assert_equal 'Shop', message['from_name']
    assert_equal %w[bcc@example.com cc@example.com user@example.com], recipients.keys.sort
    assert_equal({ 'to_name' => 'User' }, recipients['user@example.com'])
    assert_includes headers['cc'], 'cc@example.com'
    refute_includes headers.values.join(' '), 'bcc@example.com'
    assert_equal '42', headers['x-order']
    assert_equal 'Test', message['subject']
    assert_equal 'Hello', message['body']['plaintext'].strip
    assert_equal 'support@example.com', message['reply_to']
    assert_equal [{ 'type' => 'text/plain', 'name' => 'a.txt', 'content' => 'YWJj' }], message['attachments']
    assert_equal 'test-job', mail.delivery_method.response['job_id']
  end

  def test_html_mail
    transport = fake_transport

    TestMailer.html_only.deliver_now

    body = JSON.parse(transport.requests[0][:body])['message']['body']
    assert_equal '<p>Hi</p>', body['html'].strip
    assert_nil body['plaintext']
  end

  def test_api_error_of_the_mail_is_the_sdk_error
    fake_transport(400, '{"status":"error","message":"Unknown recipient","code":204}')

    error = assert_raises(ApiError) { TestMailer.welcome.deliver_now }

    assert_equal ApiError::KIND_API, error.kind
    assert_equal 204, error.error_code
    assert_equal 400, error.http_status
    assert_equal 'email/send', error.api_method
    refute error.retryable?
  end
end
