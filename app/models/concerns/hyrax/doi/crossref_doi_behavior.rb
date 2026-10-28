# frozen_string_literal: true
module Hyrax
  module DOI
    module CrossrefDOIBehavior
      extend ActiveSupport::Concern

      included do
        property :doi_status_when_public, predicate: ::RDF::URI('http://samvera.org/ns/hyrax/doi#doi_status_when_public'), multiple: false do |index|
          index.as :stored_sortable
        end

        validates :doi_status_when_public, inclusion: { in: Hyrax::DOI::CrossrefRegistrar::STATES }, allow_nil: true
      end

      # Override
      def doi_registrar
        'crossref'
      end
    end

    # Also support camel-case CrossRefDOIBehavior alias
    CrossRefDOIBehavior = CrossrefDOIBehavior
  end
end

