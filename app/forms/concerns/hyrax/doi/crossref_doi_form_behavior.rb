# frozen_string_literal: true
module Hyrax
  module DOI
    module CrossrefDOIFormBehavior
      extend ActiveSupport::Concern

      included do
        self.terms += [:doi_status_when_public]

        delegate :doi_status_when_public, to: :model
      end

      def secondary_terms
        super - [:doi_status_when_public]
      end
    end

    # Also support camel-case CrossRefDOIFormBehavior alias
    CrossRefDOIFormBehavior = CrossrefDOIFormBehavior
  end
end

