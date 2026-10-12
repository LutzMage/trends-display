# app/services/lm_studio.rb
require "net/http"
require "json"
require "base64"

class IaService
  BASE_URL     = ENV['EMBEDDINGS_URL']
  EMBED_MODEL  = ENV['EMBED_MODEL']
  VISION_MODEL = ENV['VISION_MODEL']

  def self.embed(text)
    body = post("/embeddings", model: EMBED_MODEL, input: [text.tr("\n", " ")])
    body.dig("data", 0, "embedding")
  end

  def self.describe_image(url)
    res = Net::HTTP.get_response(URI(url))
    raise "image fetch failed: HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    bytes, mime = normalize_image(res.body)
    data_url = "data:#{mime};base64,#{Base64.strict_encode64(bytes)}"

    body = post("/chat/completions",
      model: VISION_MODEL,
      temperature: 0,
      max_tokens: 150,
      messages: [{
        role: "user",
        content: [
          { type: "text", text: "Describe this image in 2-3 sentences: main subject, setting, style. No preamble." },
          { type: "image_url", image_url: { url: data_url } }
        ]
      }]
    )
    body.dig("choices", 0, "message", "content").to_s.strip
  end

  # Returns [bytes, mime] as JPEG or PNG, which vision models reliably accept.
  def self.normalize_image(bytes)
    case sniff_mime(bytes)
    when "image/jpeg" then [bytes, "image/jpeg"]
    when "image/png"  then [bytes, "image/png"]
    else
      # WebP, GIF, AVIF, etc. → re-encode as JPEG.
      require "vips"
      [Vips::Image.new_from_buffer(bytes, "").jpegsave_buffer(Q: 90), "image/jpeg"]
    end
  end

  def self.sniff_mime(bytes)
    head = bytes.byteslice(0, 12).b
    return "image/jpeg" if head.start_with?("\xFF\xD8\xFF".b)
    return "image/png"  if head.start_with?("\x89PNG".b)
    return "image/webp" if head.start_with?("RIFF".b) && head.byteslice(8, 4) == "WEBP".b
    return "image/gif"  if head.start_with?("GIF8".b)
    "application/octet-stream"
  end

  def self.post(path, payload)
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 120
    res = http.post(uri.path, payload.to_json, "Content-Type" => "application/json")
    raise "LM Studio #{path} failed: HTTP #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body)
  end

  private_class_method :post, :normalize_image, :sniff_mime
end