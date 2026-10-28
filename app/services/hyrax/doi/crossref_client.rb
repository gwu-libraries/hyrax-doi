# frozen_string_literal: true
require 'faraday'
require 'nokogiri'

module Hyrax
  module DOI
    class CrossrefClient
      attr_reader :username, :password, :prefix, :mode

      TEST_BASE_URL = "https://test.crossref.org/"
      PRODUCTION_BASE_URL = "https://doi.crossref.org/"
      REST_API_BASE_URL = "https://api.crossref.org/"

      def initialize(username:, password:, prefix:, mode: :production)
        @username = username
        @password = password
        @prefix = prefix
        @mode = mode
      end

      # Mint a DOI identifier string using the configured prefix.
      # Crossref assigns prefixes to members who then supply their own unique suffixes.
      def create_draft_doi
        "#{prefix}/#{SecureRandom.uuid}"
      end

      # Submit metadata (and landing URL inside the Crossref XML) to Crossref deposit servlet
      # @param doi [String]
      # @param metadata [String] Crossref deposit XML (doi_batch)
      # @return [String] the DOI
      def put_metadata(doi, metadata)
        file_part = upload_file_part(metadata)

        payload = {
          'operation' => 'doMDUpload',
          'login_id' => username,
          'login_passwd' => password,
          'fname' => file_part
        }

        response = connection.post('servlet/deposit', payload)
        raise Error.new('Failed creating metadata for DOI', response) if response.status != 200 || response_failed?(response.body)

        doi
      end

      # Fetch metadata for a DOI from Crossref
      def get_metadata(doi)
        response = rest_connection.get("works/#{doi}/transform/application/vnd.crossref.unixref+xml")
        raise Error.new('Failed getting DOI metadata', response) unless response.status == 200

        Nokogiri::XML(response.body).remove_namespaces!
      end

      # Fetch target URL for a DOI from Crossref
      def get_url(doi)
        response = rest_connection.get("works/#{doi}")
        raise Error.new('Failed getting DOI url', response) unless response.status == 200

        data = JSON.parse(response.body)
        data.dig('message', 'resource', 'primary', 'URL') || data.dig('message', 'URL')
      end

      class Error < RuntimeError
        attr_reader :status

        def initialize(msg = '', response = nil)
          if response
            @status = response.status
            msg += "\n#{@status}: #{response.reason_phrase}\n"
            msg += response.body.to_s
          end

          super(msg)
        end
      end

      private

      def connection
        Faraday.new(url: base_url) do |c|
          c.request :multipart if c.respond_to?(:request)
          c.request :url_encoded
          c.adapter Faraday.default_adapter
        end
      end

      def rest_connection
        Faraday.new(url: REST_API_BASE_URL) do |c|
          c.adapter Faraday.default_adapter
        end
      end

      def upload_file_part(content)
        if defined?(Faraday::Multipart::FilePart)
          Faraday::Multipart::FilePart.new(StringIO.new(content), 'application/xml', 'crossref_deposit.xml')
        elsif defined?(Faraday::UploadIO)
          Faraday::UploadIO.new(StringIO.new(content), 'application/xml', 'crossref_deposit.xml')
        else
          Faraday::FilePart.new(StringIO.new(content), 'application/xml', 'crossref_deposit.xml')
        end
      end

      def response_failed?(body)
        body = body.to_s
        return true if body.include?('Invalid user login ID and/or password')
        return true if body.include?('<title>FAILURE</title>')
        return true if body.include?('status="Failure"')
        return true if body.include?('status="failed"')

        # If it contains FAILURE and does not contain SUCCESS
        body.include?('FAILURE') && !body.include?('SUCCESS')
      end

      def base_url
        mode&.to_sym == :production ? PRODUCTION_BASE_URL : TEST_BASE_URL
      end
    end

    # Also support camel-case CrossRefClient alias
    CrossRefClient = CrossrefClient
  end
end

