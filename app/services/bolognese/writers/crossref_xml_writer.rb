# frozen_string_literal: true
require 'bolognese'
require 'nokogiri'
require 'securerandom'

module Bolognese
  module Writers
    module CrossrefXmlWriter
      # Crosswalks Bolognese metadata into a Crossref deposit XML document (<doi_batch>)
      #
      # @param options [Hash]
      # @option options [String] :doi Override the DOI string
      # @option options [String] :url Override the resolving landing URL
      # @option options [String] :depositor_name Depositor organization or username
      # @option options [String] :depositor_email Depositor contact email
      # @option options [String] :registrant Registrant name
      # @option options [String] :batch_id Batch identifier
      # @option options [String] :posted_content_type Crossref posted_content type (e.g. preprint, other)
      # @return [String] formatted Crossref XML
      def crossref_xml(options = {})
        target_doi = options[:doi] || normalize_crossref_doi(doi)
        target_url = options[:url] || url || "https://doi.org/#{target_doi}"
        depositor_name = options[:depositor_name] || self.options.try(:[], :depositor_name) || 'Hyrax'
        depositor_email = options[:depositor_email] || self.options.try(:[], :depositor_email) || 'noreply@example.org'
        registrant = options[:registrant] || self.options.try(:[], :registrant) || depositor_name
        batch_id = options[:batch_id] || SecureRandom.uuid
        timestamp = options[:timestamp] || Time.now.utc.strftime('%Y%m%d%H%M%S')
        content_type = options[:posted_content_type] || determine_posted_content_type

        date_year, date_month, date_day = extract_crossref_date_parts
        authors = Array(creators).presence || Array(contributors)
        work_titles = Array(titles).map { |t| t.is_a?(Hash) ? t['title'] : t.to_s }.compact.presence || ['[Untitled]']
        desc = extract_crossref_description
        group_title = options[:group_title] || extract_crossref_publisher_name

        builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.doi_batch(
            'xmlns' => 'http://www.crossref.org/schema/4.4.2',
            'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
            'version' => '4.4.2',
            'xsi:schemaLocation' => 'http://www.crossref.org/schema/4.4.2 http://www.crossref.org/schemas/crossref4.4.2.xsd'
          ) do
            xml.head do
              xml.doi_batch_id batch_id
              xml.timestamp timestamp
              xml.depositor do
                xml.depositor_name depositor_name
                xml.email_address depositor_email
              end
              xml.registrant registrant
            end

            xml.body do
              xml.posted_content('type' => content_type) do
                xml.group_title group_title if group_title.present? && group_title != ':unav'

                if authors.present?
                  xml.contributors do
                    authors.each_with_index do |author, index|
                      given_name, family_name = parse_crossref_author_name(author)
                      sequence = index.zero? ? 'first' : 'additional'
                      xml.person_name('sequence' => sequence, 'contributor_role' => 'author') do
                        xml.given_name given_name if given_name.present?
                        xml.surname family_name.presence || given_name.presence || 'Unknown'
                      end
                    end
                  end
                end

                xml.titles do
                  work_titles.each do |t|
                    xml.title t
                  end
                end

                xml.posted_date do
                  xml.month format('%02d', date_month) if date_month.present?
                  xml.day format('%02d', date_day) if date_day.present?
                  xml.year date_year
                end

                if desc.present?
                  xml.abstract('xmlns' => 'http://www.ncbi.nlm.nih.gov/JATS1') do
                    xml.p desc
                  end
                end

                xml.doi_data do
                  xml.doi target_doi
                  xml.resource target_url
                end
              end
            end
          end
        end

        builder.to_xml
      end

      private

      def normalize_crossref_doi(val)
        return nil if val.blank?
        val.to_s.sub(%r{\Ahttps?://(dx\.)?doi\.org/}, '')
      end

      def determine_posted_content_type
        model_type = types.is_a?(Hash) ? types['resourceType'].to_s.downcase : ''
        case model_type
        when /preprint/
          'preprint'
        when /working.*paper/
          'working_paper'
        when /dissertation|thesis/
          'dissertation'
        when /report/
          'report'
        else
          'other'
        end
      end

      def parse_crossref_author_name(author)
        author = author.stringify_keys if author.respond_to?(:stringify_keys)
        family_name = author['familyName']
        given_name = author['givenName']

        if family_name.blank? && given_name.blank? && author['name'].present?
          name = author['name'].to_s.strip
          if name.include?(',')
            family_name, given_name = name.split(',', 2).map(&:strip)
          else
            parts = name.split(' ')
            family_name = parts.pop
            given_name = parts.join(' ')
          end
        end

        [given_name, family_name]
      end

      def extract_crossref_date_parts
        year = publication_year.presence || Time.now.year
        month = nil
        day = nil

        date_str = Array(dates).map { |d| d.is_a?(Hash) ? d['date'] : d.to_s }.first
        if date_str.present?
          begin
            parsed = Date.parse(date_str)
            year = parsed.year
            month = parsed.month
            day = parsed.day
          rescue StandardError
            # Keep year
          end
        end

        [year, month, day]
      end

      def extract_crossref_description
        return nil if descriptions.blank?
        Array(descriptions).map { |d| d.is_a?(Hash) ? d['description'] : d.to_s }.compact.join("\n\n").presence
      end

      def extract_crossref_publisher_name
        case publisher
        when Hash
          publisher['name']
        when String
          publisher
        else
          Array(publisher).first.to_s.presence
        end
      end
    end
  end
end

