require "excon"
require "json"
require "re-zip/api/error"
require "re-zip/api/version"

module REZIP
  module API
    class Client
      DEFAULT_HEADERS = {
        "Accept" => "application/json",
        "Accept-Language" => "en-US",
        "Accept-Version" => "2.0",
        "User-Agent" => "rezip-ruby-client, v#{REZIP::API::VERSION}"
      }.freeze

      Request = Struct.new(:method, :path, :body, :headers, :query) # rubocop:disable Lint/StructNewOverride

      def initialize(bearer: nil, username: nil, password: nil, base_uri: "https://api.re-zip.com", options: {})
        opts = {
          read_timeout: options.fetch(:read_timeout, 60),
          write_timeout: options.fetch(:write_timeout, 60),
          connect_timeout: options.fetch(:connect_timeout, 60),
          json_opts: options.fetch(:json_opts, nil)
        }

        if bearer
          opts[:headers]  = { "Authorization" => "Bearer #{bearer}" }
        else
          opts[:user]     = Excon::Utils.escape_uri(username) if username
          opts[:password] = Excon::Utils.escape_uri(password) if password
        end

        @connection = Excon.new(base_uri, opts)
      end

      %i[get post patch put delete head].each do |method|
        define_method(method) do |path, **options, &block|
          headers = @connection.data.fetch(:headers, {}).merge(DEFAULT_HEADERS).merge(options.fetch(:headers, {}))

          # TODO: Excon doesn't seem to like sub-sub domains, so we need to set Host header manually
          headers["Host"] || headers["Host"] = @connection.connection.fetch(:host)

          body = begin
            data = options.fetch(:body, "")
            if headers["Content-Type"] == "application/json" && data.instance_of?(Hash)
              data.to_json
            else
              data
            end
          end

          req = Request.new(
            method,
            path,
            scrub_body(body.dup, headers["Content-Type"]),
            headers,
            options.fetch(:query, {})
          ).freeze

          res = @connection.request(**req.to_h)
          error = REZIP::API::Error.by_status_code(res.status, res.body, res.headers, req)

          if !options.fetch(:raw, false) && res.headers["Content-Type"] =~ %r{application/json}
            res.body = JSON.parse(res.body, options[:json_opts] || @connection.data[:json_opts])
          end

          if block
            # Raise error if not specified as fourth block parameter
            raise error if error && block.parameters.size < 4

            block.call(res.body, res.status, res.headers, error)
          else
            raise error if error

            [res.body, res.status, res.headers]
          end
        end
      end

      private

      def scrub_body(body, content_type)
        return "" if body.to_s.empty?

        if ["application/json", "application/x-www-form-urlencoded"].include?(content_type)
          body
        else
          "<scrubbed for Content-Type #{content_type}>"
        end
      end
    end
  end
end
