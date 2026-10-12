# Run with: bin/rails runner script/fake_likes.rb

USER_ID         = 41 # User we want to affect
HANDLES         = %w[veganrecipes.bsky.social yookikiku.bsky.social astronomy2024.bsky.social] # For testing embeddings purposes
LIKES_PER_HANDLE = 3

user = User.find(USER_ID)
embedded_post_ids = Embedding.where(embeddable_type: "Post").select(:embeddable_id)
already_liked     = user.interactions.where(event_type: :like).select(:post_id)

HANDLES.each do |handle|
  author = User.find_by(username: handle)
  unless author
    puts "#{handle}: not found, skipping"
    next
  end

  posts = author.posts
                .where(id: embedded_post_ids)
                .where.not(id: already_liked)
                .order("RANDOM()")
                .limit(LIKES_PER_HANDLE)

  puts "#{handle}:"
  posts.each do |post|
    user.interactions.create!(post:, event_type: :like)
    puts "  liked ##{post.id}  #{post.text.truncate(60)}"
  end
  puts "  (no posts with embeddings available)" if posts.empty?
end

puts "\nLikes for user #{USER_ID}: #{user.interactions.where(event_type: :like).count}"
