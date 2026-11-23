class Api::LikesController < ApplicationController
  include InteractionToggle

  private

  def toggle_event = "like"

  def toggle_json(liked)
    { liked:, like_count: current_post.interactions.like_event.count }
  end
end
