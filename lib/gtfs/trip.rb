module GTFS
  class Trip
    include GTFS::Model

    has_required_attrs :route_id, :service_id, :trip_id
    has_optional_attrs :trip_headsign, :trip_short_name, :direction_id, :block_id, :shape_id, :wheelchair_accessible, :bikes_allowed
    attr_accessor *attrs
    attr_accessor :stop_sequence
    attr_accessor :shape_dist_traveled

    collection_name :trips
    required_file true
    uses_filename 'trips.txt'

    def id
      self.trip_id
    end

    def stops
      self.stop_sequence.to_set
      # self.feed.children(self)
    end
  end
end
