require 'mail'

module Griddler
  module Sparkpost
    class Adapter
      def initialize(params)
        @params = params
      end

      def self.normalize_params(params)
        adapter = new(params)
        adapter.normalize_params
      end

      def normalize_params
        begin
          msg = params['_json'][0]['msys']['relay_message']
          content = msg['content']
          mail = Mail.read_from_string(content['email_rfc822'])
          # SparkPost documentation isn't clear on friendly_from.
          # In case there's a full email address (e.g. "Test User <test@test.com>"), strip out junk
          clean_from = msg['friendly_from'].split('<').last.delete('>').strip
          params.merge(
            to: content['to'],
            from: clean_from,
            cc: content['cc'].nil? ? [] : content['cc'],
            subject: content['subject'],
            text: content['text'],
            html: content['html'],
            headers: headers_raw(content['headers']), # spec calls for raw headers, so convert back
            attachments: attachment_files(mail)
          )
        rescue
        end
      end

      private

      attr_reader :params

      def headers_raw(arr)
        # sparkpost gives us an array of header maps, with just one key and value (to preserve order)
        # we will convert them back to the raw headers here
        arr.inject([]) { |raw_headers, obj|
          raw_headers.push("#{obj.keys.first}: #{obj.values.first}")
        }.join("\r\n")
      end

      def attachment_files(mail)
        mail.attachments.map { |attachment|
          ActionDispatch::Http::UploadedFile.new({
            filename: attachment.filename,
            type: attachment.mime_type,
            tempfile: create_tempfile(attachment)
          })
        }
      end

      def create_tempfile(attachment)
        filename = attachment.filename.gsub(/\/|\\/, '_')
        tempfile = Tempfile.new(filename, Dir::tmpdir, encoding: 'ascii-8bit')
        content = attachment.body.decoded
        tempfile.write(content)
        tempfile.rewind
        tempfile
      end
    end
  end
end
