# Finds Bluesky handles per interest that actually post images.
# Run with: ruby handles_by_interest.rb   (or bin/rails runner handles_by_interest.rb)
# Prints a Ruby hash you can paste into your seed script.
# encoding: utf-8
require "net/http"
require "json"

API = ENV['BLUESKY_HANDLERS_API']

# Several queries per interest: plain topic words return lots of
# organizations and policy accounts, so add photo-heavy terms.
INTERESTS = {
  food:     ["recipes", "home cooking", "baking", "food photography"],
  travel:   ["travel photography", "travel blogger", "backpacking", "landscape photography"],
  crafting: ["crochet", "knitting", "woodworking", "pottery", "embroidery"],
  arts:     ["illustrator", "painter", "watercolor", "digital artist"],
  science:  ["astronomy", "astrophotography", "biologist", "science communicator", "geology"]
}

HANDLES_PER_INTEREST = 8
CANDIDATES_PER_QUERY = 25
MIN_IMAGE_POSTS      = 10 # out of the last 100 media posts
NSFW_PATTERN         = /18\+|🔞|nsfw|adult|kink|onlyfans|minors dni/i

def get(path, params)
  uri = URI("#{API}/#{path}")
  uri.query = URI.encode_www_form(params)
  res = Net::HTTP.get_response(uri)
  return nil unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
rescue StandardError => e
  warn "  request failed (#{path}): #{e.message}"
  nil
end

def search_actors(query)
  data = get("app.bsky.actor.searchActors", q: query, limit: CANDIDATES_PER_QUERY)
  data ? data["actors"] : []
end

def safe_actor?(actor)
  return false if actor["labels"].to_a.any? # moderation/self labels (e.g. adult content)
  text = "#{actor['displayName']} #{actor['description']}"
  !text.match?(NSFW_PATTERN)
end

def image_post?(post)
  embed = post["embed"] or return false
  case embed["$type"]
  when "app.bsky.embed.images#view"          then embed["images"].to_a.any?
  when "app.bsky.embed.recordWithMedia#view" then embed.dig("media", "images").to_a.any?
  else false
  end
end

# Counts image posts (with text short enough for the Post model) by this author.
def usable_image_posts(handle)
  data = get("app.bsky.feed.getAuthorFeed", actor: handle, limit: 100, filter: "posts_with_media")
  return 0 unless data
  data["feed"].count do |item|
    next false if item["reason"] # repost
    post = item["post"]
    text = post.dig("record", "text").to_s.strip
    post.dig("author", "handle") == handle && !text.empty? && text.length <= 250 && image_post?(post)
  end
end

seen = {}
result = {}

INTERESTS.each do |interest, queries|
  warn "== #{interest}"
  picked = []

  queries.each do |query|
    break if picked.size >= HANDLES_PER_INTEREST

    search_actors(query).each do |actor|
      break if picked.size >= HANDLES_PER_INTEREST
      handle = actor["handle"]
      next if seen[handle] || handle == "handle.invalid"
      seen[handle] = true
      next unless safe_actor?(actor)

      count = usable_image_posts(handle)
      warn "  #{handle.ljust(40)} #{count} usable image posts"
      picked << handle if count >= MIN_IMAGE_POSTS
      sleep 0.2 # stay well under the public rate limit
    end
  end

  result[interest] = picked
end

puts "HANDLES_BY_INTEREST = {"
result.each do |interest, handles|
  puts "  #{interest}: %w[#{handles.join(' ')}],"
end
puts "}"