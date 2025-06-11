require "./spec_helper"

describe AZBlob do
  it "should encode paths properly" do
    AZBlob::Client.encode_path("test.cr").should eq "test.cr"
    AZBlob::Client.encode_path("hello/test.cr").should eq "hello/test.cr"
    AZBlob::Client.encode_path("/hello/test.cr").should eq "hello/test.cr"
  end
end
