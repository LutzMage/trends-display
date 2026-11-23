class Api::SavesController < ApplicationController
  include InteractionToggle

  private

  def toggle_event = "save"

  def toggle_json(saved)
    { saved: }
  end
end
