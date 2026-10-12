class GenerateEmbeddingsJob < ApplicationJob
  queue_as :default
  retry_on Errno::ECONNREFUSED, Net::ReadTimeout, wait: :polynomially_longer, attempts: 5

  def perform(post)
    upsert_embedding(post, :text) { post.text }

    return unless post.image?

    upsert_embedding(post, :image) { IaService.describe_image(post.media_url) }
  end

  private

  def upsert_embedding(post, type)
    return if post.embeddings.exists?(embedding_type: type, embedding_model: IaService::EMBED_MODEL)

    vector = IaService.embed(yield)

    post.embeddings.create!(
      embedding_type:  type,
      embedding_model: IaService::EMBED_MODEL,
      dimensions:      vector.size,
      vector:          pad(vector)
    )
  end

  def pad(vector)
    size = vector.size
    if size > Embedding::MAX_DIMENSIONS
      raise ArgumentError, "#{IaService::EMBED_MODEL} returned #{size} dimensions, max is #{Embedding::MAX_DIMENSIONS}"
    end
    vector + Array.new(Embedding::MAX_DIMENSIONS - size, 0.0)
  end
end
