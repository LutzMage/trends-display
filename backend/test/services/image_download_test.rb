require "test_helper"
require "net/http" # stubbed below before ImageDownload (which requires it) is loaded

# Uses the default DOWNLOAD_HOSTS (cdn.bsky.app). No test reaches the network.
class ImageDownloadTest < ActiveSupport::TestCase
  ALLOWED_URL = "https://cdn.bsky.app/img/feed_fullsize/plain/did:plc:abc/cid@jpeg"

  # A response object whose body arrives in chunks, as Net::HTTP streams it.
  ChunkedResponse = Struct.new(:chunks) do
    def read_body(&) = chunks.each(&)
  end

  # Replaces the network call: ImageDownload.get answers [status, content type, body].
  def responding_with(status: 200, content_type: "image/jpeg", body: "image-bytes", &)
    stub_singleton(ImageDownload, :get, ->(_uri) { [ status, content_type, body ] }, &)
  end

  def expecting_no_request(&)
    stub_singleton(ImageDownload, :get, ->(uri) { flunk "unexpected request to #{uri}" }, &)
  end

  test "fetches an image from an allowed host" do
    responding_with(content_type: "image/jpeg", body: "jpeg-bytes") do
      image = ImageDownload.fetch(ALLOWED_URL)

      assert_equal "jpeg-bytes", image.body
      assert_equal "image/jpeg", image.content_type
      assert_equal "jpg", image.extension
    end
  end

  test "names the file after the image type, ignoring content type parameters" do
    {
      "image/png" => "png",
      "image/webp; charset=binary" => "webp",
      "IMAGE/GIF" => "gif"
    }.each do |content_type, extension|
      responding_with(content_type:) do
        assert_equal extension, ImageDownload.fetch(ALLOWED_URL).extension
      end
    end
  end

  test "never requests a URL outside the allowlist" do
    expecting_no_request do
      [
        "https://example.com/a.jpg",
        "https://cdn.bsky.app.evil.example/a.jpg",
        "http://cdn.bsky.app/a.jpg",
        "ftp://cdn.bsky.app/a.jpg",
        "not a url"
      ].each do |url|
        assert_raises(ImageDownload::NotAllowed, url) { ImageDownload.fetch(url) }
      end
    end
  end

  test "a response that is not a 200 image is unavailable" do
    [
      { status: 404, content_type: "text/html" },
      { status: 301, content_type: nil },
      { status: 200, content_type: "text/html" },
      { status: 200, content_type: "image/svg+xml" },
      { status: 200, content_type: nil }
    ].each do |response|
      responding_with(**response) do
        assert_raises(ImageDownload::Unavailable, response.inspect) { ImageDownload.fetch(ALLOWED_URL) }
      end
    end
  end

  test "a network error is unavailable" do
    [ Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError ].each do |error|
      stub_singleton(Net::HTTP, :start, ->(*) { raise error }) do
        assert_raises(ImageDownload::Unavailable, error.name) { ImageDownload.get(URI(ALLOWED_URL)) }
      end
    end
  end

  test "reads a body of up to 10 MB" do
    assert_equal "aaabb", ImageDownload.read_capped(ChunkedResponse.new([ "aaa", "bb" ]))

    full = ImageDownload.read_capped(ChunkedResponse.new([ "x" * ImageDownload::MAX_BYTES ]))
    assert_equal ImageDownload::MAX_BYTES, full.bytesize
  end

  test "stops reading a body over 10 MB" do
    oversized = ChunkedResponse.new([ "x" * ImageDownload::MAX_BYTES, "y" ])

    assert_raises(ImageDownload::Unavailable) { ImageDownload.read_capped(oversized) }
  end
end
