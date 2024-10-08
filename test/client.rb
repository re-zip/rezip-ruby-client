# Simplecov must be loaded and configured before anything else
require "simplecov"
require "simplecov-console"
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::Console]
)
SimpleCov.start do
  add_filter "/vendor/"
  minimum_coverage 100
end

require "excon"
require "json"
require "minitest/autorun"
require "pry"
require "re-zip/api/client"

Excon.defaults[:mock] = true

describe REZIP::API::Client do
  before do
    # Excon expects two hashes
    Excon.stub({}, { body: "Unknown Stub", status: 500 })
  end

  after do
    Excon.stubs.clear
  end

  it "set default headers" do
    Excon.stub(
      { path: "/ping" },
      lambda do |request_params|
        {
          headers: request_params[:headers],
          status: 200
        }
      end
    )

    client = REZIP::API::Client.new
    _, _, headers = *client.get("/ping")

    _(headers["Accept-Version"]).must_equal "2.0"
    _(headers["User-Agent"]).must_equal "rezip-ruby-client, v#{REZIP::API::VERSION}"
  end

  it "handles authentication" do
    Excon.stub(
      { path: "/ping" },
      lambda do |request_params|
        {
          headers: request_params[:headers],
          status: 200
        }
      end
    )

    client = REZIP::API::Client.new(password: "secret")
    _, _, headers = *client.get("/ping")

    _(headers["Authorization"]).must_equal "Basic OnNlY3JldA=="

    client = REZIP::API::Client.new(bearer: "token")
    _, _, headers = *client.get("/ping")

    _(headers["Authorization"]).must_equal "Bearer token"
  end

  describe "JSON <=> Hash conversion of body" do
    subject { REZIP::API::Client.new }

    it "returns JSON string if content type is not set" do
      Excon.stub(
        { path: "/ping" },
        lambda do |request_params|
          {
            body: request_params[:body],
            status: 200
          }
        end
      )

      # client return JSON string
      subject.post(
        "/ping",
        body: { "foo" => "bar" },
        headers: { "Content-Type" => "application/json" }
      ).tap do |response,|
        _(JSON.parse(response)).must_equal({ "foo" => "bar" })
      end
    end

    it "returns ruby Hash if content type is set" do
      Excon.stub(
        { path: "/ping" },
        lambda do |request_params|
          {
            body: request_params[:body],
            headers: { "Content-Type" => "application/json" },
            status: 200
          }
        end
      )

      # client returns Ruby Hash with string keys
      subject.post(
        "/ping",
        body: { "foo" => "bar" },
        headers: { "Content-Type" => "application/json" }
      ).tap do |response,|
        _(response).must_equal({ "foo" => "bar" })
      end

      # client returns Ruby Hash with symbol keys
      subject.post(
        "/ping",
        body: { "foo" => "bar" },
        headers: { "Content-Type" => "application/json" },
        json_opts: { symbolize_names: true }
      ).tap do |response,|
        _(response).must_equal({ :foo => "bar" })
      end
    end
  end

  describe "request with block" do
    subject { REZIP::API::Client.new }

    it "is called for success" do
      Excon.stub(
        { path: "/ping" },
        {
          status: 200,
          body: %({"message":"pong"}),
          headers: { "Content-Type" => "application/json" }
        }
      )

      called = subject.get("/ping", json_opts: { symbolize_names: true }) do |body, status, headers, error|
        _(body[:message]).must_equal "pong"
        _(status).must_equal 200
        _(headers["Content-Type"]).must_equal "application/json"
        _(error).must_be :nil?

        true
      end
      _(called).must_equal true
    end

    it "is called for non success with error block param" do
      Excon.stub({ path: "/ping" }, { status: 404 })

      called = subject.get "/ping", json_opts: { symbolize_names: true } do |_, status, _, error|
        _(status).must_equal 404
        _(error.class).must_equal REZIP::API::Error::NotFound

        true
      end
      _(called).must_equal true
    end

    it "is not called for non success without error block param" do
      Excon.stub({ path: "/ping" }, { status: 404 })

      assert_raises REZIP::API::Error::NotFound do
        subject.get "/ping", json_opts: { symbolize_names: true } do |_, status|
          _(status).must_equal 405
        end
      end
    end
  end

  describe "Error handling" do
    it "raises predefined errors" do
      client = REZIP::API::Client.new

      assert_raises REZIP::API::Error::BadRequest do
        Excon.stub({ path: "/ping" }, { status: 400 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::Unauthorized do
        Excon.stub({ path: "/ping" }, { status: 401 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::PaymentRequired do
        Excon.stub({ path: "/ping" }, { status: 402 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::Forbidden do
        Excon.stub({ path: "/ping" }, { status: 403 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::NotFound do
        Excon.stub({ path: "/ping" }, { status: 404 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::MethodNotAllowed do
        Excon.stub({ path: "/ping" }, { status: 405 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::NotAcceptable do
        Excon.stub({ path: "/ping" }, { status: 406 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::Conflict do
        Excon.stub({ path: "/ping" }, { status: 409 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::TooManyRequest do
        Excon.stub({ path: "/ping" }, { status: 429 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::InternalServerError do
        Excon.stub({ path: "/ping" }, { status: 500 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::BadGateway do
        Excon.stub({ path: "/ping" }, { status: 502 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::ServiceUnavailable do
        Excon.stub({ path: "/ping" }, { status: 503 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error::GatewayTimeout do
        Excon.stub({ path: "/ping" }, { status: 504 })
        client.get("/ping")
      end

      assert_raises REZIP::API::Error do
        Excon.stub({ path: "/ping" }, { status: 418 })
        client.get("/ping")
      end
    end

    it "decorates predefined errors" do
      client = REZIP::API::Client.new

      e = assert_raises REZIP::API::Error do
        Excon.stub({ path: "/ping" }, { status: 409, body: "Conflict", headers: { "Foo" => "bar" } })
        client.post(
          "/ping",
          body: "foo=bar&baz=qux",
          headers: { "Content-Type" => "application/x-www-form-urlencoded" }
        )
      end
      _(e.status).must_equal 409
      _(e.body).must_equal "Conflict"
      _(e.headers).must_equal({ "Foo" => "bar" })
      _(e.request.method).must_equal :post
      _(e.request.body).must_equal "foo=bar&baz=qux"
      _(e.request.headers.fetch("Accept-Version")).must_equal "2.0"
      _(e.request.headers.fetch("User-Agent")).must_equal "rezip-ruby-client, v#{REZIP::API::VERSION}"
      _(e.request.query).must_equal({})

      e = assert_raises REZIP::API::Error do
        Excon.stub({ path: "/upload" }, { status: 409, body: "Conflict", headers: { "Foo" => "bar" } })
        client.post(
          "/upload",
          body: "binary data",
          headers: { "Content-Type" => "image/png" },
          query: { "foo" => "bar" }
        )
      end

      _(e.inspect).must_equal <<~ERR.strip
        #<REZIP::API::Error::Conflict: status=409, body="Conflict", headers={"Foo"=>"bar"} \
        request=#<struct REZIP::API::Client::Request method=:post, path="/upload", \
        body="<scrubbed for Content-Type image/png>", \
        headers={"User-Agent"=>"rezip-ruby-client, v#{REZIP::API::VERSION}", \
        "Accept"=>"application/json", "Accept-Language"=>"en-US", \
        "Accept-Version"=>"2.0", "Content-Type"=>"image/png", "Host"=>"api.re-zip.com"}, query={"foo"=>"bar"}>>
      ERR
    end
  end
end
