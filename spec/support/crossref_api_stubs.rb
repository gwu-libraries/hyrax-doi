# frozen_string_literal: true
RSpec.configure do |config|
  config.before(crossref_api: true) do
    # Crossref deposit with bad credentials
    stub_request(:post, URI.join(Hyrax::DOI::CrossrefClient::TEST_BASE_URL, "servlet/deposit"))
      .with(body: hash_including('login_id' => 'bad-username', 'login_passwd' => 'bad-password'))
      .to_return(status: 200, body: '<html><head><title>FAILURE</title></head><body><h2>FAILURE</h2><p>Invalid user login ID and/or password</p></body></html>')

    # Crossref deposit with unknown prefix/doi
    stub_request(:post, URI.join(Hyrax::DOI::CrossrefClient::TEST_BASE_URL, "servlet/deposit"))
      .with(body: hash_including('login_id' => 'username', 'login_passwd' => 'password'))
      .to_return do |request|
        if request.body.include?('unknown-prefix')
          { status: 200, body: '<html><head><title>FAILURE</title></head><body><h2>FAILURE</h2><p>Record rejected by Crossref</p></body></html>' }
        else
          { status: 200, body: '<html><head><title>SUCCESS</title></head><body><h2>SUCCESS</h2><p>Your batch submission was successfully received.</p></body></html>' }
        end
      end

    # GET metadata from Crossref REST API
    stub_request(:get, URI.join(Hyrax::DOI::CrossrefClient::REST_API_BASE_URL, "works/#{prefix}/draft-doi/transform/application/vnd.crossref.unixref+xml"))
      .to_return(status: 200, body: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<crossref_result xmlns=\"http://www.crossref.org/qrschema/3.0\" version=\"3.0\">
  <query_result>
    <body status=\"resolved\">
      <query status=\"resolved\">
        <doi type=\"journal_article\">#{prefix}/draft-doi</doi>
      </query>
    </body>
  </query_result>
</crossref_result>")

    stub_request(:get, URI.join(Hyrax::DOI::CrossrefClient::REST_API_BASE_URL, "works/#{prefix}/unknown-doi/transform/application/vnd.crossref.unixref+xml"))
      .to_return(status: 404, body: 'Resource not found.')

    # GET URL from Crossref REST API
    stub_request(:get, URI.join(Hyrax::DOI::CrossrefClient::REST_API_BASE_URL, "works/#{prefix}/draft-doi"))
      .to_return(status: 200, body: "{\"status\":\"ok\",\"message-type\":\"work\",\"message\":{\"DOI\":\"#{prefix}/draft-doi\",\"URL\":\"https://www.moomin.com/en/\"}}")

    stub_request(:get, URI.join(Hyrax::DOI::CrossrefClient::REST_API_BASE_URL, "works/#{prefix}/unknown-doi"))
      .to_return(status: 404, body: "{\"status\":\"failed\",\"message\":\"Resource not found.\"}")
  end
end

