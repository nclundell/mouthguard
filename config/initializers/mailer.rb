unless ENV.key?("SECRET_KEY_BASE_DUMMY")
  api_key = Rails.application.credentials.resend&.api_key
  raise ArgumentError, "Missing resend.api_key in Rails credentials" if api_key.blank?

  Resend.api_key = api_key
end
