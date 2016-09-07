require 'json'

describe GTFS::Fetch do
  let (:url) { 'http://httpbin.org/get' }
  let (:url_redirect) { 'http://httpbin.org/redirect-to?url=http%3A%2F%2Fhttpbin.org%2Fget' }
  let (:url_redirect_relative) { 'http://httpbin.org/redirect-to?url=%2Fget' }
  let (:url_redirect_many) { 'http://httpbin.org/absolute-redirect/6' }
  let (:url_404) { 'http://httpbin.org/status/404' }
  let (:url_binary) { 'http://httpbin.org/stream-bytes/1024?seed=0' }
  let (:url_ssl) { 'https://httpbin.org/get'}

  context '.request' do
    it 'returns a response' do
      VCR.use_cassette('fetch') do
        response = {}
        GTFS::Fetch.request(url) { |resp| response = JSON.parse(resp.read_body) }
        response['url'].should eq(url)
      end
    end

    it 'follows a redirect' do
      VCR.use_cassette('fetch_redirect') do
        response = {}
        GTFS::Fetch.request(url_redirect) { |resp| response = JSON.parse(resp.read_body) }
        response['url'].should eq(url)
      end
    end

    it 'follows a relative redirect' do
      VCR.use_cassette('fetch_redirect_relative') do
        response = {}
        GTFS::Fetch.request(url_redirect_relative) { |resp| response = JSON.parse(resp.read_body) }
        response['url'].should eq(url)
      end
    end

    it 'follows SSL' do
      VCR.use_cassette('fetch_ssl') do
        response = {}
        GTFS::Fetch.request(url_ssl) { |resp| response = JSON.parse(resp.read_body) }
        response['url'].should eq(url_ssl)
      end
    end

    it 'follows a redirect no more than limit times' do
      VCR.use_cassette('fetch_redirect_fail') do
        expect {
          GTFS::Fetch.request(url_redirect_many, limit:2) { |resp| response = JSON.parse(resp.read_body) }
        }.to raise_error(ArgumentError)
      end
    end

    it 'raises errors' do
      VCR.use_cassette('fetch_fetch_404') do
        expect {
          GTFS::Fetch.request(url_404, limit:2) { |resp| response = JSON.parse(resp.read_body) }
        }.to raise_error(Net::HTTPServerException)
      end
    end
  end

  context '.download' do
    it 'downloads to temp file' do
      VCR.use_cassette('fetch') do
        data = {}
        GTFS::Fetch.download_to_tempfile(url) { |filename| data = JSON.parse(File.read(filename))}
        data['url'].should eq(url)
      end
    end

    it 'removes tempfile' do
      VCR.use_cassette('fetch') do
        path = nil
        GTFS::Fetch.download_to_tempfile(url) { |filename| path = filename }
        File.exists?(path).should be false
      end
    end

    it 'downloads binary data' do
      VCR.use_cassette('fetch_binary') do
        data = nil
        GTFS::Fetch.download_to_tempfile(url_binary) { |filename| data = File.read(filename) }
        Digest::MD5.new.update(data).hexdigest.should eq('355c7ebd00db307b91ecd23a4215174a')
      end
    end

    it 'has a progress callback' do
      VCR.use_cassette('fetch_binary') do
        processed = 0
        progress = lambda { |count, total| processed = count }
        GTFS::Fetch.download_to_tempfile(url_binary, progress: progress) { |filename| data = File.read(filename) }
        processed.should eq 1024
      end
    end

    it 'allows files smaller than maximum size' do
      VCR.use_cassette('fetch_binary') do
        data = nil
        GTFS::Fetch.download_to_tempfile(url_binary, maxsize:2048) { |filename| data = File.read(filename) }
        Digest::MD5.new.update(data).hexdigest.should eq('355c7ebd00db307b91ecd23a4215174a')
      end
    end

    it 'raises error if response larger than maximum size' do
      VCR.use_cassette('fetch_binary') do
        expect {
          GTFS::Fetch.download_to_tempfile(url_binary, maxsize:128) { |filename| }
        }.to raise_error(IOError)
      end
    end
  end
end
