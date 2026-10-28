# frozen_string_literal: true
require 'rails_helper'

describe Bolognese::Writers::CrossrefXmlWriter do
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
      title: ['Test Work Title'],
      creator: ['Jansson, Tove', 'Lars Jansson'],
      publisher: ['Schildts'],
      description: ['A story about Moominvalley residents.'],
      doi: ['10.1234/test-doi'],
      date_created: ['2020-05-15']
    }
  end

  let(:metadata) do
    input_data = work.attributes.merge(has_model: work.has_model.first, doi: Array(work.doi)).to_json
    Bolognese::Metadata.new(input: input_data, from: 'hyrax_work')
  end

  describe '#crossref_xml' do
    let(:xml_output) { metadata.crossref_xml(url: 'https://example.com/concern/generic_works/1') }
    let(:doc) { Nokogiri::XML(xml_output).remove_namespaces! }

    it 'generates a valid XML document with doi_batch root' do
      expect(doc.xpath('/doi_batch')).not_to be_empty
      expect(doc.xpath('/doi_batch/@version').text).to eq '4.4.2'
    end

    it 'includes head metadata' do
      expect(doc.xpath('//head/doi_batch_id').text).not_to be_blank
      expect(doc.xpath('//head/timestamp').text).not_to be_blank
      expect(doc.xpath('//head/depositor/depositor_name').text).to eq 'Hyrax'
      expect(doc.xpath('//head/depositor/email_address').text).to eq 'noreply@example.org'
      expect(doc.xpath('//head/registrant').text).to eq 'Hyrax'
    end

    it 'includes titles' do
      expect(doc.xpath('//posted_content/titles/title').text).to eq 'Test Work Title'
    end

    it 'includes authors with sequence and contributor_role' do
      authors = doc.xpath('//posted_content/contributors/person_name')
      expect(authors.size).to eq 2

      first_author = authors[0]
      expect(first_author.attr('sequence')).to eq 'first'
      expect(first_author.attr('contributor_role')).to eq 'author'
      expect(first_author.xpath('surname').text).to eq 'Jansson'
      expect(first_author.xpath('given_name').text).to eq 'Tove'

      second_author = authors[1]
      expect(second_author.attr('sequence')).to eq 'additional'
      expect(second_author.attr('contributor_role')).to eq 'author'
      expect(second_author.xpath('surname').text).to eq 'Jansson'
      expect(second_author.xpath('given_name').text).to eq 'Lars'
    end

    it 'includes posted_date' do
      expect(doc.xpath('//posted_content/posted_date/year').text).to eq '2020'
    end

    it 'includes abstract' do
      expect(doc.xpath('//posted_content/abstract/p').text).to eq 'A story about Moominvalley residents.'
    end

    it 'includes doi_data with doi and URL resource' do
      expect(doc.xpath('//posted_content/doi_data/doi').text).to eq '10.1234/test-doi'
      expect(doc.xpath('//posted_content/doi_data/resource').text).to eq 'https://example.com/concern/generic_works/1'
    end

    it 'includes group_title from publisher' do
      expect(doc.xpath('//posted_content/group_title').text).to eq 'Schildts'
    end

    context 'with custom options' do
      let(:xml_output) do
        metadata.crossref_xml(
          doi: '10.5678/custom-doi',
          url: 'https://custom.example.org/work/1',
          depositor_name: 'Custom Depositor',
          depositor_email: 'custom@example.org',
          registrant: 'Custom Press',
          posted_content_type: 'preprint'
        )
      end

      it 'respects custom options' do
        expect(doc.xpath('//head/depositor/depositor_name').text).to eq 'Custom Depositor'
        expect(doc.xpath('//head/depositor/email_address').text).to eq 'custom@example.org'
        expect(doc.xpath('//head/registrant').text).to eq 'Custom Press'
        expect(doc.xpath('//posted_content/@type').text).to eq 'preprint'
        expect(doc.xpath('//posted_content/doi_data/doi').text).to eq '10.5678/custom-doi'
        expect(doc.xpath('//posted_content/doi_data/resource').text).to eq 'https://custom.example.org/work/1'
      end
    end
  end
end

