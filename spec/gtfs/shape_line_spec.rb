require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::ShapeLine do
  let(:valid_local_source) do
    File.expand_path(File.dirname(__FILE__) + '/../fixtures/valid_gtfs.zip')
  end
  let(:shapes) {[
      GTFS::Shape.new(shape_id: '63542', shape_pt_sequence: '5', shape_pt_lon: "-76.662018", shape_pt_lat: "39.350739", shape_dist_traveled: "0.1631"),
      GTFS::Shape.new(shape_id: '63542', shape_pt_sequence: '4', shape_pt_lon: "-76.661949", shape_pt_lat: "39.35067", shape_dist_traveled: "0.1539"),
      GTFS::Shape.new(shape_id: '63542', shape_pt_sequence: '3', shape_pt_lon: "-76.660767", shape_pt_lat: "39.350719", shape_dist_traveled: "0.0517"),
      GTFS::Shape.new(shape_id: '63542', shape_pt_sequence: '2', shape_pt_lon: "-76.6605", shape_pt_lat: "39.350742", shape_dist_traveled: "0.0286"),
      GTFS::Shape.new(shape_id: '63542', shape_pt_sequence: '1', shape_pt_lon: "-76.660172", shape_pt_lat: "39.350792", shape_dist_traveled: "0.0"),
  ]}
  let(:shape_line) { GTFS::ShapeLine.from_shapes(shapes) }

  context 'load_shape_lines' do
    let(:data_source) {valid_local_source}
    let(:opts) {{}}
    it 'has a ShapeLine' do
      source = GTFS::ZipSource.new(data_source, opts)
      source.load_shape_lines
      sl = source.shape_line('63542')
      sl.shape_id.should eq('63542')
    end
  end

  context '.from_shapes' do
    it 'creates ShapeLine from shapes' do
      sl = GTFS::ShapeLine.from_shapes(shapes)
      sl.shape_id.should eq('63542')
      sl.coordinates.size.should eq(5)
      sl.coordinates[0][0].should be_within(0.01).of(-76.660172)
      sl.coordinates[0][1].should be_within(0.01).of(39.350792)
      sl.shape_dist_traveled.size.should eq(5)
      sl.shape_dist_traveled[0].should be_within(0.01).of(0.0)
      sl.shape_dist_traveled[-1].should be_within(0.01).of(0.1631)
    end
  end

  context '#size' do
    it 'returns shape size' do
      shape_line.size.should eq(5)
    end
  end

  context '#coordinates' do
    it 'returns shape coordinates' do
      shape_line.coordinates.size.should eq(5)
      shape_line.coordinates[0][0].should be_within(0.01).of(-76.660172)
      shape_line.coordinates[0][1].should be_within(0.01).of(39.350792)
    end
  end

  context '#shape_dist_traveled' do
    it 'returns shape_dist_traveled' do
      shape_line.shape_dist_traveled.size.should eq(5)
      shape_line.shape_dist_traveled[0].should be_within(0.01).of(0.0)
      shape_line.shape_dist_traveled[-1].should be_within(0.01).of(0.1631)
    end
  end

  context '#shape' do
    it 'returns shape index' do
      shape_line.shape(0).should eq(shapes.sort_by { |i| i.shape_pt_sequence.to_i }[0])
    end
  end

  context '#each_shape' do
    it 'iterates through shapes' do
      count = 0
      shape_line.each_shape { |i| count += 1 }
      count.should eq(5)
    end
  end

  context '#each' do
    it 'iterates through coordinates' do
      count = 0
      shape_line.each { |i| count += 1 }
      count.should eq(5)
    end
  end

  context 'Enumerable' do
    it 'supports map' do
      result = shape_line.map { |i| true }
      result.should eq([true]*5)
    end
  end
end
