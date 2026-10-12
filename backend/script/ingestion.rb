# Seeds Post records (text + image) from Bluesky author feeds.
# Run with: bin/rails runner db/seeds/bluesky_seed.rb
require "net/http"
require "json"

# Paste the output of handles_by_interest.rb here.
HANDLES_BY_INTEREST = {
  food: %w[healthyrecipes.bsky.social alltherecipes.bsky.social fujifilmrecipes.bsky.social veganrecipes.bsky.social professorrecipes.substack.com awrecipes.bsky.social lilyrecipes.bsky.social kwikarecipes.bsky.social],
  travel: %w[dennisdunnam.bsky.social travelshots.bsky.social thousandvoyages.bsky.social shawphotography.bsky.social unravelwt.com madgreek2024.bsky.social grumpysteff.bsky.social jaycee-visionlogic.eurosky.social],
  crafting: %w[debbiecrochets.bsky.social jencarole.bsky.social crochetnivore.bsky.social aoibheni.bsky.social crochetlady.bsky.social rustymarcum.bsky.social erlern.bsky.social 123crochetsarah.bsky.social],
  arts: %w[rosuuri.com rpancoast.bsky.social yookikiku.bsky.social neal-illustrator.bsky.social kachin4649.bsky.social mathiasball.bsky.social pbmoj.bsky.social wolftapioca.bsky.social],
  science: %w[astronomers.bsky.social astronomy.bsky.social apod.shinyakato.dev astro4edu.bsky.social thenrao.bsky.social sjbastro.bsky.social astronomyedinburgh.bsky.social astronomy2024.bsky.social],
}

FEED_URL           = ENV['BLUESKY_API_URL']
POSTS_PER_HANDLE   = 30
MAX_PAGES          = 5
MAX_TEXT           = 250

def fetch_page(handle, cursor)
  uri = URI(FEED_URL)
  params = { actor: handle, limit: 100, filter: "posts_with_media" }
  params[:cursor] = cursor if cursor
  uri.query = URI.encode_www_form(params)

  res = Net::HTTP.get_response(uri)
  unless res.is_a?(Net::HTTPSuccess)
    warn "  #{handle}: HTTP #{res.code}, skipping"
    return nil
  end
  JSON.parse(res.body)
rescue StandardError => e
  warn "  #{handle}: #{e.class} #{e.message}, skipping"
  nil
end

def first_image_url(embed)
  return nil unless embed
  case embed["$type"]
  when "app.bsky.embed.images#view"          then embed.dig("images", 0, "fullsize")
  when "app.bsky.embed.recordWithMedia#view" then embed.dig("media", "images", 0, "fullsize")
  end
end

def user_for(author)
  handle = author["handle"]
  User.find_or_create_by!(username: handle) do |u|
    u.email = "#{handle.parameterize}@example.com"
  end
end

total = 0

HANDLES_BY_INTEREST.each do |interest, handles|
  puts "== #{interest}"

  handles.each do |handle|
    saved = 0
    cursor = nil
    user = nil

    MAX_PAGES.times do
      data = fetch_page(handle, cursor) or break

      data["feed"].each do |item|
        break if saved >= POSTS_PER_HANDLE
        next if item["reason"] # repost, not this author's content

        post = item["post"]
        next unless post.dig("author", "handle") == handle

        text = post.dig("record", "text").to_s.strip
        next if text.empty? || text.length > MAX_TEXT

        image_url = first_image_url(post["embed"])
        next unless image_url
        next if Post.exists?(media_url: image_url) # makes re-runs safe

        user ||= user_for(post["author"])
        user.posts.create!(text: text, media_type: :image, media_url: image_url)
        saved += 1
      end

      cursor = data["cursor"]
      break if cursor.nil? || saved >= POSTS_PER_HANDLE
      sleep 0.2
    end

    puts "  #{handle.ljust(40)} #{saved} posts"
    total += saved
  end
end

puts "Done: #{total} posts created."