# frozen_string_literal: true
module Hyrax
  module DOI
    class CrossrefRegistrar < Hyrax::Identifier::Registrar
      STATES = %w[draft registered findable].freeze

      class_attribute :prefix, :username, :password, :mode, :depositor_name, :depositor_email, :registrant

      def initialize(builder: Hyrax::Identifier::Builder.new(prefix: self.prefix))
        super
      end

      ##
      # @param object [#id]
      #
      # @return [#identifier]
      def register!(object: work)
        doi = Array(object.try(:doi)).first

        # Return the existing DOI or nil if nothing needs to be done
        return Struct.new(:identifier).new(doi) unless register?(object)

        # Mint a DOI (if necessary)
        doi ||= mint_draft_doi(object: object)

        # Submit metadata and url to Crossref when appropriate based on status
        submit_to_crossref(object, doi) if should_submit?(object)

        # Return the doi (old or new)
        Struct.new(:identifier).new(doi)
      end

      def mint_draft_doi(object: nil)
        hint = object&.id || SecureRandom.uuid
        if builder.respond_to?(:build)
          builder.build(hint: hint)
        else
          client.create_draft_doi
        end
      end

      private

      # Should the work be submitted for registration (or updating)?
      # @return [boolean]
      def register?(work)
        doi_enabled_work_type?(work) &&
          doi_minting_enabled? &&
          valid_status?(work)
      end

      def valid_status?(work)
        return true unless work.respond_to?(:doi_status_when_public) && work.doi_status_when_public.present?

        work.doi_status_when_public.in?(Hyrax::DOI::CrossrefRegistrar::STATES)
      end

      # Check if work should be submitted to Crossref API
      def should_submit?(work)
        return public?(work) unless work.respond_to?(:doi_status_when_public) && work.doi_status_when_public.present?

        case work.doi_status_when_public
        when 'findable'
          public?(work)
        when 'registered'
          true
        when 'draft'
          false
        else
          false
        end
      end

      # Check if work is Crossref DOI enabled
      def doi_enabled_work_type?(work)
        work.class.ancestors.include?(Hyrax::DOI::DOIBehavior) && work.class.ancestors.include?(Hyrax::DOI::CrossrefDOIBehavior)
      end

      def doi_minting_enabled?
        true
      end

      def public?(work)
        work.visibility == Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
      end

      def client
        @client ||= Hyrax::DOI::CrossrefClient.new(username: self.username, password: self.password, prefix: self.prefix, mode: self.mode)
      end

      # Submit the metadata to Crossref via HTTPS POST
      def submit_to_crossref(work, doi)
        xml = work_to_crossref_xml(work, doi)
        client.put_metadata(doi, xml)
      end

      # NOTE: default_url_options[:host] must be set for this method to work
      def work_url(work)
        Rails.application.routes.url_helpers.polymorphic_url(work)
      end

      def work_to_crossref_xml(work, doi)
        input_data = work.attributes.merge(has_model: work.has_model.first, doi: Array(doi)).to_json
        meta = Bolognese::Metadata.new(input: input_data, from: 'hyrax_work')
        meta.crossref_xml(
          doi: doi,
          url: work_url(work),
          depositor_name: self.depositor_name || self.username,
          depositor_email: self.depositor_email,
          registrant: self.registrant || self.depositor_name || self.username
        )
      end
    end

    # Also support camel-case CrossRefRegistrar alias
    CrossRefRegistrar = CrossrefRegistrar
  end
end
