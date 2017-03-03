module GTFS
  class ShapeLine
    include Enumerable
    attr_accessor :shape_id, :shapes

    def self.from_shapes(shapes)
      self.new(shapes.first.shape_id, shapes.sort_by { |i| i.shape_pt_sequence.to_i })
    end

    def initialize(shape_id=nil, shapes=nil)
      @shape_id = shape_id
      @shapes = shapes || []
    end

    def shape(index)
      @shapes[index]
    end

    def each_shape(&block)
      @shapes.each(&block)
    end

    def coordinates
      @shapes.map { |i| [s_to_f(i.shape_pt_lon), s_to_f(i.shape_pt_lat)] }
    end

    def shape_dist_traveled
      @shapes.map { |i| s_to_f(i.shape_dist_traveled) }
    end

    def each(&block)
      coordinates.each(&block)
    end

    def size
      @shapes.size
    end

    private

    def s_to_f(value)
      value.nil? ? nil : value.to_f
    end
  end
end
