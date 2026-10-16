# UniOne Ruby on Rails 1.1.2

Web API 1.90

Quickstart guide: [Send emails with Ruby](https://docs.unione.io/en/send-with-ruby) · Docs for LLMs: [llms.txt](https://docs.unione.io/llms.txt) · [API reference](https://docs.unione.io/en/web-api-ref)

Ruby on Rails integration of the [UniOne Ruby SDK](https://github.com/unione-repo/unione-ruby-sdk) (`unione`): the API client in the application config (`config.unione`), a webhook endpoint with signature check, a Action Mailer transport that sends through `email/send`.

## Install

```bash
bundle add unione-rails
```

Requirements: Ruby 2.7+, Rails 6.1+.

## Get an API key

1. Sign up at [cp.unione.io](https://cp.unione.io/en/user/registration/).
2. Copy your API key from [Settings → Security → API](https://cp.unione.io/en/settings/security/api).
3. Put it in an environment variable:

```bash
export UNIONE_API_KEY="your-api-key"
```

The package reads it from `UNIONE_API_KEY` (see the configuration below).

> **Server-side only.** Use this package in backend code: API routes, server functions, workers.
> Never ship the API key to a browser or a mobile app, and never commit it.

## Configuration

Settings are read from the environment by default:

```ruby
# .env / environment: UNIONE_API_KEY=YOUR_API_KEY
# or config/application.rb:
config.unione.api_key = ENV.fetch('UNIONE_API_KEY')
config.unione.host = 'us1.unione.io'
config.action_mailer.delivery_method = :unione
```

| Option | Environment variable | Default | Description |
|---|---|---|---|
| `config.unione.api_key` | `UNIONE_API_KEY` |  | User or project API key (required). |
| `config.unione.host` | `UNIONE_HOST` | `api.unione.io` | API host (datacenter: `api.unione.io`, `eu1.unione.io`, `us1.unione.io`) or a full base URL. |
| `config.unione.timeout` | `UNIONE_TIMEOUT` | `30` | Request timeout, seconds. |
| `config.unione.webhook_key` | `UNIONE_WEBHOOK_KEY` |  | API key the webhooks are signed with (the key of the user/project of the webhook), if it differs from the API key. |
| `config.unione.webhook_path` | `UNIONE_WEBHOOK_PATH` | `/unione/webhook` | Path of the webhook endpoint. |

The API key can also be stored in the credentials (`unione: { api_key: ... }`). The webhook route `unione_webhook` is a Rack endpoint (no CSRF, no session); `config.unione.webhook_enabled = false` turns it off.

## Send your first email — no DNS setup

Every account can send test email right away from a **sandbox domain**: pre-verified, DKIM and SPF already set.
It delivers only to addresses you confirm.

The examples use the API client of the package (see the configuration above).

**1. Get your sandbox domain** (`domain/get-sandbox-domain`). The call creates the domain on first use and returns the same one afterwards.

```ruby
response = UniOne::Wrapper.client.domain.get_sandbox_domain
puts response.domain
```

**2. Confirm your inbox** (`confirmed-email/create`). UniOne sends a confirmation email; click the link in it within 48 hours.

```ruby
ConfirmedEmail = UniOne::Api::ConfirmedEmail::Model

response = UniOne::Wrapper.client.confirmed_email.create(ConfirmedEmail::ConfirmedEmailRequest.new(
  email: 'you@example.com'
))
puts response.status
```

Check the status with `confirmed-email/list` — your address should show `"status": "confirmed"`.

**3. Send the email** (`email/send`) from any address on the sandbox domain to the confirmed address.

```ruby
Common = UniOne::Common::Model
Email = UniOne::Api::Email::Model

response = UniOne::Wrapper.client.email.send_email(Email::EmailSendRequest.new(
  message: Email::MessageObject.new(
    recipients: [
      Email::MessageObjectRecipientsItem.new(
        email: 'you@example.com'
      )
    ],
    body: Common::BodyObject.new(
      html: '<p>It works!</p>'
    ),
    subject: 'Hello from UniOne',
    from_email: 'noreply@<sandbox-domain>'
  )
))
puts response.job_id
```

### What you get back

```json
{
  "status": "success",
  "job_id": "1ZymBc-00041N-9X",
  "emails": [
    "you@example.com"
  ]
}
```

On error the API returns `status: "error"`, a `message` and a numeric `code`:

```json
{
  "status": "error",
  "code": 102,
  "message": "Error ID:83274F98-C7D5-11F1-B221-6214FF8707B1. Can not decode key wrongkey"
}
```

### Same flow with curl

```bash
BASE=https://api.unione.io/en/transactional/api/v1

curl -s -X POST $BASE/domain/get-sandbox-domain.json \
  -H "Content-Type: application/json" -H "X-API-KEY: $UNIONE_API_KEY" -d '{}'

curl -s -X POST $BASE/confirmed-email/create.json \
  -H "Content-Type: application/json" -H "X-API-KEY: $UNIONE_API_KEY" \
  -d '{"email": "you@example.com"}'

curl -s -X POST $BASE/email/send.json \
  -H "Content-Type: application/json" -H "X-API-KEY: $UNIONE_API_KEY" \
  -d '{
        "message": {
          "recipients": [
            {
              "email": "you@example.com"
            }
          ],
          "from_email": "noreply@<sandbox-domain>",
          "subject": "Hello from UniOne",
          "body": {
            "html": "<p>It works!</p>"
          }
        }
      }'
```

## Sending mail

Messages of the Action Mailer go through [email/send](https://docs.unione.io/en/web-api-ref#email-send): from, to/cc/bcc, reply-to, subject, HTML and text parts, attachments, inline images and `X-*` headers.

```ruby
class OrderMailer < ApplicationMailer
  def shipped(order)
    headers['X-Order-Id'] = order.id.to_s
    attachments['invoice.pdf'] = order.invoice_pdf
    mail(to: order.email, cc: order.manager_email, subject: 'Order shipped')
  end
end

message = OrderMailer.shipped(order).deliver_now
message.delivery_method.response['job_id']
```

## Webhooks

The endpoint answers `GET` with 200 OK (the URL check of [webhook/set](https://docs.unione.io/en/web-api-ref#webhook-set)) and accepts the `POST` notifications: it checks the `auth` field (MD5 of the request body in which the `auth` value is replaced by the API key), answers 401 to a wrong signature, and passes the notification and each of its events to the application.

```ruby
# config/initializers/unione.rb
ActiveSupport::Notifications.subscribe('event.unione') do |*, payload|
  event = payload[:event]
  data = event.event_data
  Rails.logger.info("UniOne #{event.event_name}: #{data&.email} #{data&.status}")
end
```

Register the URL of the endpoint with `webhook/set`, e.g. `https://example.com/unione/webhook`.

## API client

Every section of the API is available on the client, see the [SDK docs](https://github.com/unione-repo/unione-ruby-sdk).

```ruby
client = UniOne::Wrapper.client
info = client.system.info
puts info.accounting&.emails_sent
```

## Sending through the API

Besides the Action Mailer, mail can be sent through the API client directly. The client calls [email/send](https://docs.unione.io/en/web-api-ref#email-send) with all of its options: templates, substitutions, metadata, tracking. Fields of the request and other examples: [Ruby SDK docs](https://github.com/unione-repo/unione-ruby-sdk/blob/HEAD/docs/Email.md#send_email).

```ruby
Common = UniOne::Common::Model
Email = UniOne::Api::Email::Model

response = UniOne::Wrapper.client.email.send_email(Email::EmailSendRequest.new(
  message: Email::MessageObject.new(
    recipients: [
      Email::MessageObjectRecipientsItem.new(
        email: 'user@example.com',
        substitutions: {
          'CustomerId' => '12452',
          'to_name' => 'John Smith',
        }
      )
    ],
    body: Common::BodyObject.new(
      html: '<b>Hello, {{to_name}}</b>',
      plaintext: 'Hello, {{to_name}}'
    ),
    subject: 'UniOne test email ',
    from_email: 'email@example.com',
    from_name: 'John Smith'
  )
))
puts response.job_id
```

## Sandbox limits

- Sends only to confirmed addresses: up to 10 per account.
- Up to 100 emails a day.
- The sandbox domain expires after 31 days; call `domain/get-sandbox-domain` again to get a new one.
- Works only with the account API key, not a project key.
- Not listed in `domain/list`; the other `domain/*` methods do not apply to it.

The sandbox is for development and testing. Do not use a sandbox domain as the sender in production.

## Before production: verify your domain

1. `domain/get-dns-records` — returns the values for your DNS records.
2. Add these records at your DNS provider (the domain page of the control panel shows them too):

   | Type | Host | Value |
   |---|---|---|
   | TXT | `@` | the `verification-record` value (`unione-validate-hash=…`) |
   | TXT | `<selector>._domainkey` (the selector is on the domain page of the control panel, e.g. `us`) | `v=DKIM1; k=rsa; p=<dkim>` |
   | TXT | `@` | `v=spf1 include:spf.unione.io ~all` |
   | CNAME | `_dmarc` | the `dmarc` value |

3. `domain/validate-verification-record`, then `domain/validate-dkim`.
4. `domain/list` — wait until the verification record is confirmed and DKIM is active.
5. Read `from_email` from your config, so switching from the sandbox needs no code change.

## Sending reliably

- **Retries:** set `message.idempotence_key` on sends that may be retried, so a repeated request does not send twice.
- **Limits:** up to 500 recipients and 10 MB per request; each attachment up to 7 MB.
- **Body:** always include `body.html` or `body.plaintext`.
- **Delivery status:** register a webhook (`webhook/set`) with a fast, idempotent HTTPS handler instead of polling.
- **Defaults:** keep the default unsubscribe footer and tracking; changing them requires UniOne support.
- **Errors:** retry `429` and `5xx` with backoff; do not retry other errors unchanged.

## Links

- [Send emails with Ruby](https://docs.unione.io/en/send-with-ruby) and other [integration guides](https://docs.unione.io/en/integrations/)
- [Web API reference](https://docs.unione.io/en/web-api-ref)
- [llms.txt](https://docs.unione.io/llms.txt) for AI coding agents
- [UniOne MCP server and agent setup](https://unione.io/en/agents)
- [Support](https://cp.unione.io/en/support)

## For package contributors

See [AGENTS.md](AGENTS.md): how this package is generated from the OpenAPI spec, built, tested and released.
