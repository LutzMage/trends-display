ENV["RAILS_ENV"] ||= "test"

# Fixtures use "test-model" embeddings, and CI has no .env.
ENV["EMBED_MODEL"] = "test-model"
# .env may already be loaded with empty values (e.g. AUTH0_CLIENT_ID=""), and ||= keeps "", so check blank.
{
  "JWT_SECRET" => "test-jwt-secret-#{'x' * 32}",
  "AUTH0_DOMAIN" => "example.auth0.test",
  "AUTH0_CLIENT_ID" => "test-client",
  "AUTH0_CLIENT_SECRET" => "test-secret",
  "AUTH0_CALLBACK_URL" => "http://localhost:3000/api/auth/google/callback",
  "FRONTEND_URL" => "http://localhost:5173"
}.each { |name, value| ENV[name] = value if ENV[name].blank? }

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Replaces a class method for the duration of the block.
    # Minitest 6 no longer ships minitest/mock; parallel workers are processes, so this stays isolated.
    def stub_singleton(klass, method_name, callable)
      original = klass.method(method_name)
      # Call through a wrapper: passing the lambda as a block would re-bind its self to klass.
      klass.define_singleton_method(method_name) { |*args, **kwargs, &block| callable.call(*args, **kwargs, &block) }
      yield
    ensure
      klass.define_singleton_method(method_name, original) if original
    end
  end
end

module ActionDispatch
  class IntegrationTest
    # Signs in without going through the sign-in endpoint. Call before the request.
    def sign_in_as(user)
      https!
      cookies[:td_session] = SessionToken.issue(user)
    end

    # The lower-cased Set-Cookie line for one cookie in the last response, or nil.
    def set_cookie_line(name)
      Array(response.headers["set-cookie"])
        .flat_map { |header| header.split("\n") }
        .find { |line| line.start_with?("#{name}=") }
        &.downcase
    end
  end
end
