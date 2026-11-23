# PUT and DELETE for a like or a save. There is at most one row per user and post, so both are idempotent
# (SPEC-003 §5). Including controllers define `toggle_event` ("like" or "save") and `toggle_json(on)`.
module InteractionToggle
  extend ActiveSupport::Concern
  include PostScoped

  included do
    before_action :require_authentication
  end

  def update
    begin
      current_user.interactions.find_or_create_by!(post: current_post, event_type: toggle_event)
    rescue ActiveRecord::RecordNotUnique
      # A concurrent PUT inserted it first, so the post is already in the requested state.
    end
    render json: toggle_json(true)
  end

  def destroy
    # destroy_by runs callbacks, so the profile update is enqueued.
    current_user.interactions.destroy_by(post: current_post, event_type: toggle_event)
    render json: toggle_json(false)
  end
end
