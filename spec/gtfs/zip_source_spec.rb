require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::ZipSource do
  let(:source_root) { File.join(File.expand_path(File.dirname(__FILE__)), '..') }
  let(:source_valid_zip) { File.join(source_root, 'fixtures', 'example.zip') }
  let(:source_nested_zip) { File.join(source_root, 'fixtures', 'example_nested.zip') }
  let(:source_nested_zip_single_source) { File.join(source_root, 'fixtures', 'example_nested_zip_single_source.zip') }
  let(:source_subfolder_single_source) { File.join(source_root, 'fixtures', 'example_subfolder_single_source.zip') }
  let(:source_fragment) { source_nested_zip + '#' + 'example_nested/nested/example.zip'}
  let(:expected_files) { ['stops.txt', 'routes.txt', 'trips.txt', 'agency.txt', 'stop_times.txt'] }

  describe '#load_archive' do
    it 'extracts nested zip' do
      feed = GTFS::ZipSource.new(source_fragment)
      feed.valid?.should be true
    end

    it 'sets @archive and @path' do
      source = source_nested_zip
      feed = GTFS::ZipSource.new(source_fragment)
      feed.source.should eq source_fragment
      feed.archive.should eq source_nested_zip
      feed.path.should be
    end
  end

  describe '.extract_nested' do
    before(:each) { 
      @tmpdir = Dir.mktmpdir
      @options = GTFS::Source::DEFAULT_OPTIONS.clone
    }
    after(:each) { FileUtils.rm_rf(@tmpdir) }

    it 'extracts flat path' do
      path = ""
      tmpdir = GTFS::ZipSource.extract_nested(source_valid_zip, path, @tmpdir, @options)
      GTFS::ZipSource.required_files_present?(Dir.entries(tmpdir)).should be true
    end

    it 'extracts nested directory' do
      path = "example_nested/example"
      tmpdir = GTFS::ZipSource.extract_nested(source_nested_zip, path, @tmpdir, @options)
      GTFS::ZipSource.required_files_present?(Dir.entries(tmpdir)).should be true
    end

    it 'extracts nested zip' do
      path = "example_nested/nested/example.zip"
      tmpdir = GTFS::ZipSource.extract_nested(source_nested_zip, path, @tmpdir, @options)
      GTFS::ZipSource.required_files_present?(Dir.entries(tmpdir)).should be true
    end

    it 'extracts nested single nested zip without fragment' do
      path = ""
      tmpdir = GTFS::ZipSource.extract_nested(source_nested_zip_single_source, path, @tmpdir, @options)
      GTFS::ZipSource.required_files_present?(Dir.entries(tmpdir)).should be true
    end
    it 'extracts nested single nested subfolders without fragment' do
      path = ""
      tmpdir = GTFS::ZipSource.extract_nested(source_nested_zip_single_source, path, @tmpdir, @options)
      GTFS::ZipSource.required_files_present?(Dir.entries(tmpdir)).should be true
    end


    it 'extracts nested multipe roots throw an exception without fragment' do
      path = ""
      expect { 
        tmpdir = GTFS::ZipSource.extract_nested(source_nested_zip, path, @tmpdir, @options)
      }.to raise_error(GTFS::AmbiguousZipException)
    end
  end

  describe '.find_gtfs_paths' do
    it 'finds root sources' do
      GTFS::ZipSource.find_gtfs_paths(source_valid_zip).should =~ [""]
    end

    it 'finds nested sources' do
      GTFS::ZipSource.find_gtfs_paths(source_nested_zip).should =~ ["example_nested/example", "example_nested/nested/example.zip#"]
    end
  end
end
