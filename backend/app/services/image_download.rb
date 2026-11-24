require "net/http"

# Fetches a post's image so the browser can save it as a file (SPEC-003 §3.7).
# The image URL is user data, so only https URLs on DOWNLOAD_HOSTS are ever requested (SSRF, SPEC-003 §5).
class ImageDownload
  class NotAllowed < StandardError; end
  class Unavailable < StandardError; end

  TYPES = { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp", "image/gif" => "gif" }.freeze
  MAX_BYTES = 10.megabytes
  NETWORK_ERRORS = [ SystemCallError, SocketError, IOError, Timeout::Error, OpenSSL::SSL::SSLError ].freeze

  Image = Data.define(:body, :content_type) do
    def extension = TYPES.fetch(content_type)
  end

  def self.fetch(url)
    uri = URI.parse(url)
    raise NotAllowed, url unless uri.is_a?(URI::HTTPS) && allowed_hosts.include?(uri.host)

    status, content_type, body = get(uri)
    content_type = content_type.to_s.split(";").first.to_s.strip.downcase
    raise Unavailable, "HTTP #{status}, #{content_type.presence || 'no content type'}" unless status == 200 && TYPES.key?(content_type)

    Image.new(body:, content_type:)
  rescue URI::InvalidURIError
    raise NotAllowed, url
  end

  # The only network call: [status, content type, body]. Redirects are not followed, so they fail the 200 check.
  def self.get(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(Net::HTTP::Get.new(uri)) do |response|
        body = read_capped(response) if response.is_a?(Net::HTTPOK)
        # Returning here also skips reading the rest of a non-200 body.
        return [ response.code.to_i, response["Content-Type"], body ]
      end
    end
  rescue *NETWORK_ERRORS => e
    raise Unavailable, "#{e.class}: #{e.message}"
  end

  # Reads the body in chunks and stops as soon as it passes MAX_BYTES.
  def self.read_capped(response)
    body = String.new # binary
    response.read_body do |chunk|
      body << chunk
      raise Unavailable, "image larger than #{MAX_BYTES} bytes" if body.bytesize > MAX_BYTES
    end
    body
  end

  def self.allowed_hosts
    ENV.fetch("DOWNLOAD_HOSTS", "cdn.bsky.app").split(",").map(&:strip).compact_blank
  end
  private_class_method :allowed_hosts
end
