class FeedQuery
  def initialize(user:, cursor:, limit:)
    @user   = user
    @cursor = decode(cursor)
    @limit  = limit
  end

  def call
    profile = @user&.embeddings&.user_profile&.find_by(embedding_model: IaService::EMBED_MODEL)
    profile ? ranked(profile) : recent
  end

  private

  def ranked(profile)
    vec  = "[#{profile.vector.join(',')}]"
    dist = ActiveRecord::Base.sanitize_sql(["embeddings.vector <=> ?::vector", vec])

    base = Embedding
      .where(embeddable_type: "Post", embedding_type: "text", embedding_model: profile.embedding_model)
      .where.not(embeddable_id: @user.posts.select(:id))
      .select("embeddings.id, embeddings.embeddable_id, (#{dist}) AS distance")
      .order(Arel.sql("distance, embeddings.id"))

    after = base
    if @cursor["d"]
      after = base.where("(#{dist}, embeddings.id) > (?, ?)", @cursor["d"], @cursor["id"])
    end

    rows = with_wrap(after, base)
    posts = Post.includes(:user).where(id: rows.map(&:embeddable_id)).index_by(&:id)

    {
      posts: rows.filter_map { |r| posts[r.embeddable_id]&.feed_json },
      next_cursor: rows.last && encode(d: rows.last.distance, id: rows.last.id)
    }
  end

  # --- Fallback: newest first ---
  def recent
    base = Post.includes(:user).order(id: :desc)
    base = base.where.not(user_id: @user.id) if @user

    after = @cursor["id"] && !@cursor["d"] ? base.where("posts.id < ?", @cursor["id"]) : base
    rows = with_wrap(after, base)

    {
      posts: rows.map(&:feed_json),
      next_cursor: rows.last && encode(id: rows.last.id)
    }
  end

  # Takes a page after the cursor; if it runs short, continues from the top.
  def with_wrap(after, from_start)
    rows = after.limit(@limit).to_a
    rows += from_start.limit(@limit - rows.size).to_a if rows.size < @limit
    rows
  end

  def encode(data) = Base64.urlsafe_encode64(data.to_json, padding: false)

  def decode(cursor)
    cursor.present? ? JSON.parse(Base64.urlsafe_decode64(cursor)) : {}
  rescue ArgumentError, JSON::ParserError
    {} # bad or stale cursor: start from the top
  end
end
