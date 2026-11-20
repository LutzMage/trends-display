ENV["RAILS_ENV"] ||= "test"

# Fixtures use "test-model" embeddings, and CI has no .env. dotenv never overrides these.
ENV["EMBED_MODEL"] = "test-model"
ENV["JWT_SECRET"] ||= "test-jwt-secret-#{'x' * 32}"
ENV["AUTH0_DOMAIN"] ||= "example.auth0.test"
ENV["AUTH0_CLIENT_ID"] ||= "test-client"
ENV["AUTH0_CLIENT_SECRET"] ||= "test-secret"

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
      klass.define_singleton_method(method_name, &callable)
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
