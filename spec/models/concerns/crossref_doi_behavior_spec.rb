# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/doi/spec/shared_specs'

describe 'Hyrax::DOI::CrossrefDOIBehavior' do
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::CrossrefDOIBehavior

      def self.name
        "WorkWithCrossrefDOI"
      end

      def self.to_s
        name
      end
    end
  end
  let(:work) { model_class.new(title: ['Moomin']) }

  it_behaves_like 'a DOI-enabled model'
  it_behaves_like 'a Crossref DOI-enabled model'

  describe '#doi_registrar' do
    it 'returns :crossref' do
      expect(work.doi_registrar).to eq 'crossref'
    end
  end
end

