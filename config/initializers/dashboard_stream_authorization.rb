module DashboardStreamAuthorization
  def subscribed
    stream_name = verified_stream_name_from_params
    if stream_name.present? && (current_user || stream_name == "dashboard_games")
      stream_from stream_name
    else
      reject
    end
  end
end

Rails.application.config.to_prepare do
  Turbo::StreamsChannel.prepend(DashboardStreamAuthorization) unless Turbo::StreamsChannel.ancestors.include?(DashboardStreamAuthorization)
end
