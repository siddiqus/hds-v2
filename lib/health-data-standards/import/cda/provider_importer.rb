require "date"
# require "date/delta"

module HealthDataStandards
  module Import
    module CDA
      class ProviderImporter < SectionImporter
        
        
        def initialize
          
        end
        
        include Singleton
        include ProviderImportUtils
        # Extract Healthcare Providers from C32
        #
        # @param [Nokogiri::XML::Document] doc It is expected that the root node of this document
        #        will have the "cda" namespace registered to "urn:hl7-org:v3"
        # @return [Array] an array of providers found in the document
        def extract_providers(doc)
          performers = doc.xpath("//cda:documentationOf/cda:serviceEvent/cda:performer")

          # extract the effective date or reporting period
          effective_time = doc.xpath("//cda:documentationOf/cda:serviceEvent/cda:effectiveTime")                    
          start_date = Time.new('1970','01','01').to_i
          end_date = nil
          
          performers.map do |performer|
            provider_perf = extract_provider_data(performer, true)
            
            # in case individual reporting periods are missing
#            if provider_perf[:start] == nil || provider_perf[:end] == nil 
            provider_perf[:start] = start_date
	          provider_perf[:end] = end_date
#  					end
						
  					if ( provider_perf[:npi] )
	            ProviderPerformance.new(start_date: provider_perf.delete(:start), end_date: provider_perf.delete(:end), npi: provider_perf[:npi], provider: find_or_create_provider(provider_perf))
  					end
          end
        end

        private
      
        def extract_provider_data(performer, use_dates=true, entity_path="./cda:assignedEntity")
          provider = {}
          entity = performer.xpath(entity_path)
          
          name = entity.at_xpath("./cda:assignedPerson/cda:name")
          provider[:title]        = extract_data(name, "./cda:prefix")
          provider[:given_name]   = extract_data(name, "./cda:given[1]")
          provider[:family_name]  = extract_data(name, "./cda:family")
          provider[:organization] = OrganizationImporter.instance.extract_organization(entity.at_xpath("./cda:representedOrganization"))
          provider[:specialty]    = extract_data(entity, "./cda:code/@code")
          time                    = performer.xpath(performer, "./cda:time")
          
          if use_dates
            provider[:start]        = extract_date(time, "./cda:low/@value")
            provider[:end]          = extract_date(time, "./cda:high/@value")
          end
          
          # NIST sample C32s use different OID for NPI vs C83, support both
          npi                     = extract_data(entity, "./cda:id[@root='2.16.840.1.113883.4.6' or @root='2.16.840.1.113883.3.72.5.2']/@extension")
          provider[:addresses] = performer.xpath("./cda:assignedEntity/cda:addr").try(:map) {|ae| import_address(ae)}
          provider[:telecoms] = performer.xpath("./cda:assignedEntity/cda:telecom").try(:map) {|te| import_telecom(te)}
          
          provider[:npi] = npi if Provider.valid_npi?(npi)
          
          provider
        end
      
        def extract_date(subject,query)
          date = extract_data(subject,query)
          date ? Date.parse(date).to_time.to_i : nil
        end
      
        # Returns nil if result is an empty string, block allows text munging of result if there is one
        def extract_data(subject, query)
          result = subject.try(:xpath,query).try(:text)
          if result == ""
            nil
          else
            result
          end
        end
      
      end
    end
  end
end
