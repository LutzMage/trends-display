Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Only the SPA, with credentials, so the session cookie is sent (SPEC-002 §4.5).
    origins ENV.fetch("FRONTEND_URL", "http://localhost:5173")

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
