# frozen_string_literal: true
require 'rails_helper'
require 'hyrax/doi/spec/shared_specs'

describe 'Hyrax::DOI::CrossrefDOIFormBehavior' do
  let(:model_class) do
    Class.new(GenericWork) do
      include Hyrax::DOI::DOIBehavior
      include Hyrax::DOI::CrossrefDOIBehavior
    end
  end
  let(:work) { model_class.new(title: ['Moomin']) }
  let(:form_class) do
    Class.new(Hyrax::GenericWorkForm) do
      include Hyrax::DOI::DOIFormBehavior
      include Hyrax::DOI::CrossrefDOIFormBehavior
    end
  end
  let(:form) { form_class.new(work, nil, nil) }

  it_behaves_like 'a DOI-enabled form'
  it_behaves_like 'a Crossref DOI-enabled form'
end

