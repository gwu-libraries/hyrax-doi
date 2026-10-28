# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/doi/spec/shared_specs'

describe 'Hyrax::DOI::CrossrefDOIPresenterBehavior' do
  let(:presenter_class) do
    Class.new(Hyrax::GenericWorkPresenter) do
      include Hyrax::DOI::DOIPresenterBehavior
      include Hyrax::DOI::CrossrefDOIPresenterBehavior
    end
  end
  let(:solr_document_class) do
    Class.new(SolrDocument) do
      include Hyrax::DOI::SolrDocument::DOIBehavior
      include Hyrax::DOI::SolrDocument::CrossrefDOIBehavior
    end
  end

  it_behaves_like 'a DOI-enabled presenter'
  it_behaves_like 'a Crossref DOI-enabled presenter'
end

