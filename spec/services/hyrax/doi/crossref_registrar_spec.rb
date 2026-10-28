# frozen_string_literal: true
require 'rails_helper'

describe 'Hyrax::DOI::CrossrefRegistrar', :crossref_api do
  let(:registrar) { Hyrax::DOI::CrossrefRegistrar.new }
  let(:username) { 'username' }
  let(:password) { 'password' }
  let(:prefix) { '10.1234' }
  let(:draft_doi) { "#{prefix}/draft-doi" }
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::CrossrefDOIBehavior

      def self.name
        "GenericWork"
      end
    end
  end
  let(:work) { model_class.create(attributes) }
  let(:attributes) do
    {
      title: [title],
      creator: [creator],
      publisher: [publisher],
      description: [description],
      doi: doi
    }
  end
  let(:title) { 'Moomin' }
  let(:creator) { 'Tove Jansson' }
  let(:publisher) { 'Schildts' }
  let(:description) { 'Swedish comic about the adventures of the residents of Moominvalley.' }
  let(:doi) { [draft_doi] }

  before do
    Hyrax::DOI::CrossrefRegistrar.username = username
    Hyrax::DOI::CrossrefRegistrar.password = password
    Hyrax::DOI::CrossrefRegistrar.prefix = prefix
    Hyrax::DOI::CrossrefRegistrar.mode = :test
  end

  describe 'initialize' do
    it 'sets a default builder with the configured prefix' do
      expect(registrar.builder.prefix).to eq prefix
    end
  end

  describe 'register!' do
    context 'with a non-DOI enabled work' do
      let(:work) { GenericWork.new }

      it 'returns a nil identifier' do
        expect(registrar.register!(object: work).identifier).to eq nil
      end
    end

    context 'when doi_status_when_public is nil' do
      context 'doi is nil' do
        let(:doi) { nil }

        it 'returns a nil identifier' do
          expect(registrar.register!(object: work).identifier).to eq nil
        end
      end

      context 'doi is supplied' do
        it 'returns supplied doi' do
          expect(registrar.register!(object: work).identifier).to eq doi.first
        end
      end
    end

    context 'when doi_status_when_public is draft' do
      before do
        work.doi_status_when_public = 'draft'
      end

      context 'doi is nil' do
        let(:doi) { nil }

        it 'returns a new doi without submitting to Crossref' do
          allow(registrar.send(:client)).to receive(:put_metadata)
          expect(registrar.register!(object: work).identifier).to match Hyrax::DOI::DOIBehavior::DOI_REGEX
          expect(registrar.send(:client)).not_to have_received(:put_metadata)
        end
      end

      context 'doi is supplied' do
        it 'returns supplied doi without submitting to Crossref' do
          allow(registrar.send(:client)).to receive(:put_metadata)
          expect(registrar.register!(object: work).identifier).to eq doi.first
          expect(registrar.send(:client)).not_to have_received(:put_metadata)
        end
      end
    end

    context 'when doi_status_when_public is registered' do
      before do
        work.doi_status_when_public = 'registered'
        allow(registrar.send(:client)).to receive(:put_metadata).and_call_original
      end

      context 'doi is nil' do
        let(:doi) { nil }

        it 'mints a new doi and submits to Crossref' do
          expect(registrar.register!(object: work).identifier).to match Hyrax::DOI::DOIBehavior::DOI_REGEX
          expect(registrar.send(:client)).to have_received(:put_metadata).with(Hyrax::DOI::DOIBehavior::DOI_REGEX, String)
        end
      end

      context 'doi is supplied' do
        it 'submits supplied doi to Crossref' do
          expect(registrar.register!(object: work).identifier).to eq doi.first
          expect(registrar.send(:client)).to have_received(:put_metadata).with(doi.first, String)
        end
      end
    end

    context 'when doi_status_when_public is findable' do
      before do
        work.doi_status_when_public = 'findable'
        allow(registrar.send(:client)).to receive(:put_metadata).and_call_original
      end

      context 'work is public' do
        before do
          work.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
        end

        it 'submits metadata to Crossref' do
          expect(registrar.register!(object: work).identifier).to eq doi.first
          expect(registrar.send(:client)).to have_received(:put_metadata).with(doi.first, String)
        end
      end

      context 'work is not public' do
        it 'does not submit metadata to Crossref until public' do
          expect(registrar.register!(object: work).identifier).to eq doi.first
          expect(registrar.send(:client)).not_to have_received(:put_metadata)
        end
      end
    end
  end

  describe 'mint_draft_doi' do
    it 'returns a minted doi with prefix' do
      expect(registrar.mint_draft_doi(object: work)).to match Hyrax::DOI::DOIBehavior::DOI_REGEX
      expect(registrar.mint_draft_doi(object: work)).to start_with("#{prefix}/")
    end
  end
end

