# frozen_string_literal: true

require 'test_helper'

# The webhook route: GET 200, POST with the signature -> ActiveSupport::Notifications, a wrong signature -> 401.
class WebhookTest < Minitest::Test
  PATH = '/unione/webhook'
  Signature = ::UniOne::Wrapper::WebhookSignature
  # A notification with two events of one user, "auth" is the placeholder of Signature.sign
  SAMPLE = <<~JSON
    {
      "auth": "00000000000000000000000000000000",
      "events_by_user": [
        {
          "user_id": 1,
          "project_id": "6432890213745872",
          "events": [
            {
              "event_name": "transactional_email_status",
              "event_data": {
                "job_id": "1a3Q2V-0000OZ-S0",
                "email": "user@example.com",
                "status": "delivered",
                "event_time": "2015-11-30 15:09:42"
              }
            },
            {
              "event_name": "transactional_spam_block",
              "event_data": {
                "block_time": "2015-11-30 15:09:42",
                "block_type": "one_smtp",
                "domain": "example.com",
                "SMTP_blocks_count": 1,
                "domain_status": "blocked"
              }
            }
          ]
        }
      ]
    }
  JSON

  def app
    Rack::MockRequest.new(Rails.application)
  end

  def post(body)
    app.post(PATH, input: body, 'CONTENT_TYPE' => 'application/json')
  end

  def signed(key = 'test-key')
    Signature.sign(SAMPLE, key)
  end

  # Status of a request, 404 also when the routing error is raised (show_exceptions off)
  def status_of
    yield.status
  rescue ActionController::RoutingError
    404
  end

  def received
    list = []
    subscribers = %w[webhook.unione event.unione].map do |name|
      ActiveSupport::Notifications.subscribe(name) { |event_name, *, payload| list << [event_name, payload] }
    end
    yield
    list
  ensure
    subscribers&.each { |subscriber| ActiveSupport::Notifications.unsubscribe(subscriber) }
  end

  def test_get_answers_200
    assert_equal 200, app.get(PATH).status
  end

  def test_signed_notification_reaches_the_subscribers
    status = nil
    list = received { status = post(signed).status }

    assert_equal 200, status
    assert_equal %w[webhook.unione event.unione event.unione], list.map(&:first)
    assert_instance_of ::UniOne::Api::Webhook::Model::WebhookCallback, list[0][1][:callback]
    assert_equal 1, list[0][1][:data]['events_by_user'][0]['user_id']
    assert_equal 'user@example.com', list[1][1][:event].event_data&.email
    assert_equal 'transactional_spam_block', list[2][1][:event].event_name
  end

  def test_wrong_signature_answers_401
    list = received do
      assert_equal 401, post(signed.sub('user@', 'evil@')).status
      assert_equal 401, post(signed('other-key')).status
      assert_equal 401, post(SAMPLE).status
    end
    assert_empty list
  end

  def test_signed_body_that_is_not_json_answers_400
    body = Signature.sign('{"auth":"00000000000000000000000000000000","events_by_user":[', 'test-key')
    assert_equal 400, post(body).status
  end

  def test_webhook_key_setting
    options = ::UniOne::Wrapper.configuration
    options.webhook_key = 'hook-key'
    assert_equal 200, post(signed('hook-key')).status
    assert_equal 401, post(signed).status
  ensure
    options.webhook_key = nil if options
  end

  # webhook_enabled = false after the routes were drawn: the endpoint passes the request on, as if it had no route
  def test_disabled_webhook_has_no_route
    options = ::UniOne::Wrapper.configuration
    options.webhook_enabled = false
    assert_equal 404, status_of { app.get(PATH) }
    assert_equal 404, status_of { post(signed) }
  ensure
    options.webhook_enabled = true if options
  end

  def test_signature
    body = signed
    assert Signature.verify(body, 'test-key')
    refute Signature.verify(body, 'other-key')
    refute Signature.verify(body, '')
    refute Signature.verify('{"events_by_user":[]}', 'test-key')
  end
end
