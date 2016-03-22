require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::LocalSource do
  let(:source_root) { File.join(File.expand_path(File.dirname(__FILE__)), '..') }
  let(:source_valid_zip) { File.join(source_root, 'fixtures', 'example.zip') }
  let(:source_nested_zip) { File.join(source_root, 'fixtures', 'example_nested.zip') }
  let(:expected_files) { ['stops.txt', 'routes.txt', 'trips.txt', 'agency.txt', 'stop_times.txt'] }

  describe '.extract_nested' do
    it 'extracts flat path' do
      path = ""
      tmp_dir = GTFS::LocalSource.extract_nested(source_valid_zip, path)
      GTFS::LocalSource.required_files_present?(Dir.entries(tmp_dir)).should be true
    end

    it 'extracts nested files' do
      path = "example_nested/example"
      tmp_dir = GTFS::LocalSource.extract_nested(source_nested_zip, path)
      GTFS::LocalSource.required_files_present?(Dir.entries(tmp_dir)).should be true
    end

    it 'extracts nested zip' do
      path = "example_nested/nested/example.zip"
      tmp_dir = GTFS::LocalSource.extract_nested(source_nested_zip, path)
      GTFS::LocalSource.required_files_present?(Dir.entries(tmp_dir)).should be true
    end
  end

  describe '.find_gtfs_paths' do
    it 'finds root sources' do
      GTFS::LocalSource.find_gtfs_paths(source_valid_zip).should =~ [""]
    end

    it 'finds nested sources' do
      GTFS::LocalSource.find_gtfs_paths(source_nested_zip).should =~ ["example_nested/example", "example_nested/nested/example.zip#"]
    end
  end
end
