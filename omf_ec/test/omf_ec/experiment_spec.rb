require 'test_helper'
require 'omf_ec/experiment'

describe OmfEc::Experiment do
  before do
    @experiment = OmfEc::Experiment.instance
  end

  it "must return id" do
    @experiment.id.wont_be_nil

    @experiment.name = 'bob'
    @experiment.id.must_match /bob-/
  end

  it "must be able to add event" do
    trigger = proc { 1 }
    @experiment.add_event('bob', trigger)
    @experiment.event('bob')[:name].must_equal "bob"
    @experiment.event('bob')[:trigger].call.must_equal 1
  end

  it "must be able to add sub group" do
    @experiment.add_sub_group('bob')
    @experiment.sub_group('bob').must_equal "bob"
  end

  it "must be able to add group" do
    proc { @experiment.add_group('bob') }.must_raise ArgumentError
    OmfEc.stub :subscribe_and_monitor, true do
      @experiment.add_group(OmfEc::Group.new('bob'))
      @experiment.group('bob').must_be_kind_of OmfEc::Group
    end
  end

  it "must be able to add resource to state" do
    @experiment.add_resource('bob', type: :test)
    @experiment.resource('bob')[:uid].must_equal 'bob'
    @experiment.resource('bob')[:type].must_equal :test
  end
end
