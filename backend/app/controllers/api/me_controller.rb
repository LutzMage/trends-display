class Api::MeController < ApplicationController
  before_action :require_authentication

  def show
    render json: current_user.account_json
  end
end
