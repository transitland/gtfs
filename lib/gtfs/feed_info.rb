module GTFS
  class FeedInfo
    include GTFS::Model

    has_required_attrs :feed_publisher_name, :feed_publisher_url, :feed_lang
    has_optional_attrs :feed_start_date, :feed_end_date, :feed_version, :feed_id, :feed_contact_email, :feed_contact_url
    attr_accessor *attrs

    collection_name :feed_infos
    required_file false
    uses_filename 'feed_info.txt'
  end
end
