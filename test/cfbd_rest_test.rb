require "test_helper"
class CfbdRestTest < ActiveSupport::TestCase
  test "fetches account info with the configured key" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { '{"name":"example","remaining":100}' }

    with_stub(Rails.application, :credentials, -> { Struct.new(:cfbd).new(Struct.new(:api_key).new("test-key")) }) do
      with_http_response(response) do |requests|
        assert_equal({ "name" => "example", "remaining" => 100 }, Cfbd::Rest.info)
        assert_equal 1, requests.size
        assert_equal "/info", requests.first.path
        assert_equal "Bearer test-key", requests.first["Authorization"]
      end
    end
  end

  test "rejects missing keys without making a request" do
    assert_raises(ArgumentError) { Cfbd::Rest.info(key: "") }
  end

  test "reports unsuccessful responses without exposing the key" do
    response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")

    with_http_response(response) do
      error = assert_raises(RuntimeError) { Cfbd::Rest.info(key: "private-key") }
      assert_match(/401/, error.message)
      refute_includes error.message, "private-key"
    end
  end

  private

  def with_http_response(response)
    requests = []
    test = self
    connection = Object.new
    connection.define_singleton_method(:request) { |request| requests << request; response }

    with_stub(Net::HTTP, :start, ->(host, port, options = {}, &block) {
      test.assert_equal "api.collegefootballdata.com", host
      test.assert_equal 443, port
      test.assert_equal true, options[:use_ssl]
      block.call(connection)
    }) { yield requests }
  end

  def with_stub(receiver, name, replacement)
    original = receiver.method(name)
    receiver.define_singleton_method(name, &replacement)
    yield
  ensure
    receiver.define_singleton_method(name, original) if original
  end
end
