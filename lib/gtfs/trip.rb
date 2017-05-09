module GTFS
  class Trip
    include GTFS::Model

    has_required_attrs :route_id, :service_id, :trip_id
    has_optional_attrs :trip_headsign, :trip_short_name, :direction_id, :block_id, :shape_id, :wheelchair_accessible, :bikes_allowed
    attr_accessor *attrs

    collection_name :trips
    required_file true
    uses_filename 'trips.txt'

    def id
      self.trip_id
    end

    def stops
      stop_sequence.to_set
    end

    def stop_sequence
      @stop_sequence ||= []
    end

    def stop_sequence=(value)
      @stop_sequence = value
    end

    def shape_dist_traveled
      @shape_dist_traveled
    end

    def shape_dist_traveled=(value)
      @shape_dist_traveled = value
    end
  end
end
