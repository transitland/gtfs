module GTFS
  class ShapeLine
    include Enumerable
    attr_accessor :shapes

    def self.from_shapes(shapes)
      self.new(shapes.sort_by { |i| i.shape_pt_sequence.to_i })
    end

    def initialize(shapes=nil)
      @shapes = shapes || []
    end

    def shape(index)
      @shapes[index]
    end

    def each_shape(&block)
      @shapes.each(&block)
    end

    def coordinates
      @shapes.map { |i| [i.shape_pt_lon.to_f, i.shape_pt_lat.to_f] }
    end

    def shape_dist_traveled
      @shapes.map { |i| i.shape_dist_traveled.to_f }
    end

    def each(&block)
      coordinates.each(&block)
    end

    def size
      @shapes.size
    end
  end
end
