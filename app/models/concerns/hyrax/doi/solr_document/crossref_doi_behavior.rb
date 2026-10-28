# frozen_string_literal: true
module Hyrax
  module DOI
    module SolrDocument
      module CrossrefDOIBehavior
        extend ActiveSupport::Concern

        included do
          attribute :doi_status_when_public, ::SolrDocument::Solr::String, "doi_status_when_public_ssi"
        end
      end

      # Also support camel-case CrossRefDOIBehavior alias
      CrossRefDOIBehavior = CrossrefDOIBehavior
    end
  end
end

