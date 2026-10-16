# frozen_string_literal: true

require 'base64'

module UniOne
  module Wrapper
    # Converts a Mail::Message to the "message" of email/send.
    #
    # - recipients: to, cc and bcc, the display name goes to the "to_name" substitution;
    # - with cc the "To" and "CC" headers are set, so every recipient sees the same headers;
    # - inline attachments become inline_attachments named by their Content-ID (cid:...);
    # - X-* and List-* / In-Reply-To / References headers are passed as is.
    module EmailPayload
      PASSED_HEADERS = %w[list-unsubscribe list-subscribe list-help list-owner list-archive in-reply-to references].freeze

      def self.from_mail(mail)
        from = addresses(mail, :from).first
        raise ArgumentError, 'The message has no sender (From)' if from.nil?

        message = {
          'recipients' => recipients(mail),
          'subject' => mail.subject.to_s,
          'from_email' => from.address
        }
        message['from_name'] = from.display_name if present?(from.display_name)
        reply_to = addresses(mail, :reply_to).first
        if reply_to
          message['reply_to'] = reply_to.address
          message['reply_to_name'] = reply_to.display_name if present?(reply_to.display_name)
        end
        body = body_parts(mail)
        message['body'] = body unless body.empty?
        headers = headers(mail)
        message['headers'] = headers unless headers.empty?
        mail.attachments.each do |part|
          inline = part.inline? && present?(part.cid)
          item = { 'type' => part.mime_type.to_s, 'name' => inline ? part.cid : part.filename.to_s,
                   'content' => Base64.strict_encode64(part.decoded) }
          (message[inline ? 'inline_attachments' : 'attachments'] ||= []) << item
        end
        message
      end

      def self.recipients(mail)
        %i[to cc bcc].flat_map { |field| addresses(mail, field) }.map do |address|
          recipient = { 'email' => address.address }
          recipient['substitutions'] = { 'to_name' => address.display_name } if present?(address.display_name)
          recipient
        end
      end

      def self.body_parts(mail)
        html = mail.html_part
        text = mail.text_part
        if html.nil? && text.nil? && !mail.multipart?
          key = mail.mime_type.to_s == 'text/html' ? 'html' : 'plaintext'
          return { key => mail.body.decoded }
        end
        { 'html' => html&.decoded, 'plaintext' => text&.decoded }.compact
      end

      def self.headers(mail)
        headers = {}
        cc = addresses(mail, :cc)
        unless cc.empty?
          headers['To'] = addresses(mail, :to).map(&:to_s).join(', ')
          headers['CC'] = cc.map(&:to_s).join(', ')
        end
        mail.header.fields.each do |field|
          name = field.name.to_s
          next unless name.downcase.start_with?('x-') || PASSED_HEADERS.include?(name.downcase)

          headers[name] = field.value.to_s
        end
        headers
      end

      def self.addresses(mail, field)
        header = mail[field]
        return [] if header.nil?

        list = header.respond_to?(:address_list) ? header.address_list : nil
        list ? list.addresses : Array(header.addrs)
      end

      def self.present?(value)
        !value.nil? && !value.to_s.empty?
      end
    end
  end
end
