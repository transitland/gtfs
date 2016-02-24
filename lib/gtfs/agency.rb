module GTFS
  class Agency
    include GTFS::Model

    has_required_attrs :agency_name, :agency_url, :agency_timezone
    has_optional_attrs :agency_id, :agency_lang, :agency_phone, :agency_fare_url
    attr_accessor *attrs

    collection_name :agencies
    required_file true
    uses_filename 'agency.txt'

    def id
      self.agency_id
    end

    def stops
      visited = Set.new
      self.routes.each do |route|
        route.trips.each do |trip|
          visited |= trip.stops
        end
      end
      visited
    end

    def trips
      visited = Set.new
      self.routes.each do |route|
        visited |= route.trips
      end
      visited
    end

    def routes
      self.feed.children(self)
    end
  end
end
