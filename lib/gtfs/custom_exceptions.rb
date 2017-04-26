module GTFS
  class InvalidSourceException < Exception
    # Base GTFS Exception class
  end

  class InvalidURLException < InvalidSourceException
    # Invalid URL or hostname
  end

  class InvalidResponseException < InvalidSourceException
    # Remote host returned error
    attr_accessor :response_code
    def initialize(msg, response_code=nil)
      super(msg)
      @response_code = response_code
    end
  end

  class InvalidFileException < InvalidSourceException
    # Invalid/missing local file
  end

  class InvalidZipException < InvalidSourceException
    # Invalid Zip
  end

  class AmbiguousZipException < InvalidZipException
    # Multiple gtfs roots found in the source
  end

  class InvalidCSVException < InvalidSourceException
    # Invalid CSV data
  end

  class InvalidEntityException < InvalidSourceException
    # Invalid entity
  end
end
