class UserProfileBuilder
  # Base weight per event. Impressions are left out: being shown a post says nothing.
  WEIGHTS = {
    "click"   => 0.3,
    "view"    => 0.5,
    "watch"   => 0.8,
    "like"    => 1.0,
    "comment" => 1.2,
    "save"    => 1.5,
    "share"   => 1.5,
    "dislike" => -1.0,
    "skip"    => -0.3
  }.freeze

  DWELL_EVENTS    = %w[view watch].freeze
  DWELL_MIN_MS    = 1_000    # under 1s counts as nothing
  DWELL_FULL_MS   = 15_000   # 15s or more counts fully
  OWN_POST_WEIGHT = 1.0
  POST_WEIGHT_RANGE = (-2.0..3.0) # keeps one post from dominating the profile
  HALF_LIFE_DAYS  = 14.0
  MAX_SIGNALS     = 300
  MODEL           = IaService::EMBED_MODEL

  def initialize(user)
    @user = user
  end

  def call
    weights = post_weights
    return if weights.values.sum <= 0 # nothing positive to learn from yet

    embeddings = Embedding.where(
      embeddable_type: "Post", embeddable_id: weights.keys,
      embedding_type: %w[text image], embedding_model: MODEL
    ).to_a
    return if embeddings.empty? # post embeddings not generated yet

    dims = embeddings.first.dimensions
    sum  = Array.new(dims, 0.0)
    embeddings.each do |e|
      w = weights[e.embeddable_id]
      e.vector.first(dims).each_with_index { |x, i| sum[i] += w * x }
    end

    norm = Math.sqrt(sum.sum { |x| x * x })
    return if norm.zero?

    save_profile(sum.map { |x| x / norm }, dims)
  end

  private

  # { post_id => combined weight }
  def post_weights
    weights = Hash.new(0.0)

    @user.interactions
         .where(event_type: WEIGHTS.keys)
         .order(created_at: :desc).limit(MAX_SIGNALS)
         .pluck(:post_id, :event_type, :duration_ms, :created_at)
         .each do |post_id, type, duration_ms, at|
           weights[post_id] += event_weight(type, duration_ms) * decay(at)
         end

    @user.posts.order(id: :desc).limit(50)
         .pluck(:id, :created_at)
         .each { |post_id, at| weights[post_id] += OWN_POST_WEIGHT * decay(at) }

    weights.transform_values { |w| w.clamp(POST_WEIGHT_RANGE) }
  end

  def event_weight(type, duration_ms)
    base = WEIGHTS.fetch(type)
    DWELL_EVENTS.include?(type) ? base * dwell_factor(duration_ms) : base
  end

  # 0.0 under 1s, rising to 1.0 at 15s. Unknown duration gets half credit.
  def dwell_factor(duration_ms)
    return 0.5 if duration_ms.nil?
    ((duration_ms - DWELL_MIN_MS).to_f / (DWELL_FULL_MS - DWELL_MIN_MS)).clamp(0.0, 1.0)
  end

  def decay(time)
    age_days = (Time.current - time) / 1.day
    0.5**(age_days / HALF_LIFE_DAYS)
  end

  def save_profile(vector, dims)
    padded = vector + Array.new(Embedding::MAX_DIMENSIONS - dims, 0.0)

    profile = @user.embeddings.find_or_initialize_by(
      embedding_type: :user_profile, embedding_model: MODEL
    )
    profile.update!(dimensions: dims, vector: padded)
  end
end
