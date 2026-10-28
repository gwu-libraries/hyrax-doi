# frozen_string_literal: true
require 'rails_helper'

describe 'Hyrax::DOI::CrossrefClient', :crossref_api do
  let(:client) { Hyrax::DOI::CrossrefClient.new(username: username, password: password, prefix: prefix, mode: :test) }
  let(:username) { 'username' }
  let(:password) { 'password' }
  let(:prefix) { '10.1234' }
  let(:draft_doi) { "#{prefix}/draft-doi" }
  let(:unknown_doi) { "#{prefix}/unknown-doi" }

  describe '#create_draft_doi' do
    it 'creates a DOI matching DOI format' do
      expect(client.create_draft_doi).to match Hyrax::DOI::DOIBehavior::DOI_REGEX
      expect(client.create_draft_doi).to start_with("#{prefix}/")
    end
  end

  describe '#put_metadata' do
    let(:metadata) { "<doi_batch><head><doi_batch_id>1</doi_batch_id></head><body><posted_content type=\"other\"><titles><title>Test</title></titles><doi_data><doi>#{draft_doi}</doi><resource>https://example.com</resource></doi_data></posted_content></body></doi_batch>" }

    it 'returns the passed doi on success' do
      expect(client.put_metadata(draft_doi, metadata)).to eq draft_doi
    end

    context 'with incorrect credentials' do
      let(:username) { 'bad-username' }
      let(:password) { 'bad-password' }

      it 'raises error with bad credentials' do
        expect { client.put_metadata(draft_doi, metadata) }.to raise_error(Hyrax::DOI::CrossrefClient::Error, /Failed creating metadata for DOI/)
      end
    end

    context 'with rejected payload' do
      let(:metadata) { "<doi_batch><doi_data><doi>unknown-prefix/1</doi></doi_data></doi_batch>" }

      it 'raises error when rejected' do
        expect { client.put_metadata(unknown_doi, metadata) }.to raise_error(Hyrax::DOI::CrossrefClient::Error, /Failed creating metadata for DOI/)
      end
    end
  end

  describe '#get_metadata' do
    it 'returns metadata document' do
      response = client.get_metadata(draft_doi)
      expect(response).to be_a Nokogiri::XML::Document
      expect(response.xpath('//doi/text()').first.to_s).to eq draft_doi
    end

    it 'errors with unknown DOI' do
      expect { client.get_metadata(unknown_doi) }.to raise_error(Hyrax::DOI::CrossrefClient::Error, /Failed getting DOI metadata/)
    end
  end

  describe '#get_url' do
    it 'returns the landing url' do
      expect(URI.parse(client.get_url(draft_doi))).to be_a URI::HTTP
    end

    it 'errors with unknown DOI' do
      expect { client.get_url(unknown_doi) }.to raise_error(Hyrax::DOI::CrossrefClient::Error, /Failed getting DOI url/)
    end
  end
end

