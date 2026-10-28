# frozen_string_literal: true
module Hyrax
  module DOI
    module CrossrefDOIPresenterBehavior
      extend ActiveSupport::Concern

      delegate :doi_status_when_public, to: :solr_document

      def doi_status
        if doi_status_when_public == 'findable' && !solr_document.public?
          'registered'
        else
          doi_status_when_public
        end
      end
    end

    # Also support camel-case CrossRefDOIPresenterBehavior alias
    CrossRefDOIPresenterBehavior = CrossrefDOIPresenterBehavior
  end
end

